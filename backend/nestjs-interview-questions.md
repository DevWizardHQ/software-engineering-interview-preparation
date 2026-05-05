# NestJS Interview Questions

**Level:** Mid to Senior  
**Topics:** Architecture, Decorators, DI, Guards, Interceptors, Pipes, TypeORM, Authentication, Testing

---

## Table of Contents

1. [Core Architecture](#core-architecture)
2. [Modules](#modules)
3. [Controllers](#controllers)
4. [Providers and Services](#providers-and-services)
5. [Dependency Injection](#dependency-injection)
6. [Middleware, Guards, Interceptors, Pipes, Filters](#middleware-guards-interceptors-pipes-filters)
7. [Database with TypeORM and Prisma](#database-with-typeorm-and-prisma)
8. [Authentication and Authorization](#authentication-and-authorization)
9. [Validation and Serialization](#validation-and-serialization)
10. [Testing](#testing)
11. [Advanced Topics](#advanced-topics)

---

## Core Architecture

### Q1. What is NestJS?

**Answer:**
NestJS is a progressive Node.js framework built with TypeScript. It is opinionated about application structure using:
- modules for organizing code
- controllers for handling HTTP
- providers/services for business logic
- dependency injection container

It uses Express (or Fastify) under the hood while adding a structured, Angular-inspired architecture.

---

### Q2. What is the NestJS application structure?

**Answer:**

```
src/
├── main.ts               ← bootstrap
├── app.module.ts         ← root module
├── users/
│   ├── users.module.ts
│   ├── users.controller.ts
│   ├── users.service.ts
│   ├── users.repository.ts
│   ├── dto/
│   │   ├── create-user.dto.ts
│   │   └── update-user.dto.ts
│   └── entities/
│       └── user.entity.ts
└── auth/
    ├── auth.module.ts
    ├── auth.controller.ts
    ├── auth.service.ts
    └── strategies/
        └── jwt.strategy.ts
```

---

### Q3. How do you bootstrap a NestJS application?

**Answer:**

```typescript
// main.ts
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableCors();
  
  await app.listen(3000);
}
bootstrap();
```

---

## Modules

### Q4. What is a NestJS Module?

**Answer:**
A module organizes related components. Every NestJS app has at least a root module (`AppModule`).

```typescript
@Module({
  imports: [TypeOrmModule.forFeature([User])], // other modules
  controllers: [UsersController],              // HTTP handlers
  providers: [UsersService, UsersRepository], // services, repos
  exports: [UsersService],                    // expose to other modules
})
export class UsersModule {}
```

---

### Q5. What is the difference between `imports`, `providers`, `exports`, and `controllers` in a module?

**Answer:**

| Property | Purpose |
|----------|---------|
| `imports` | Other modules whose exported providers this module needs |
| `controllers` | Controllers that belong to this module |
| `providers` | Services, repositories, factories in this module |
| `exports` | Providers other modules can inject when they import this module |

---

### Q6. What is a global module?

**Answer:**
A module decorated with `@Global()` is registered once and its exports are available everywhere without needing to import the module.

```typescript
@Global()
@Module({
  providers: [ConfigService],
  exports: [ConfigService],
})
export class ConfigModule {}
```

Use sparingly — tight coupling. Prefer explicit imports.

---

### Q7. What is a dynamic module?

**Answer:**
A module that accepts configuration to customize its providers at import time.

```typescript
@Module({})
export class DatabaseModule {
  static forRoot(options: DatabaseOptions): DynamicModule {
    return {
      module: DatabaseModule,
      providers: [
        { provide: 'DB_OPTIONS', useValue: options },
        DatabaseService,
      ],
      exports: [DatabaseService],
    };
  }
}

// Usage
DatabaseModule.forRoot({ host: 'localhost', port: 5432 })
```

---

## Controllers

### Q8. What is a Controller in NestJS?

**Answer:**
Handles incoming HTTP requests and returns responses. Uses decorators to define routes.

```typescript
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  findAll(@Query() query: PaginationDto) {
    return this.usersService.findAll(query);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.usersService.findOne(id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateUserDto: UpdateUserDto) {
    return this.usersService.update(+id, updateUserDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('id') id: string) {
    return this.usersService.remove(+id);
  }
}
```

---

### Q9. What are common parameter decorators in controllers?

**Answer:**

| Decorator | Extracts |
|-----------|---------|
| `@Param('id')` | Route parameter |
| `@Query()` | Query string |
| `@Body()` | Request body |
| `@Headers('auth')` | HTTP header |
| `@Req()` | Full request object |
| `@Res()` | Full response object |
| `@Ip()` | Client IP |
| `@UploadedFile()` | File upload |

---

## Providers and Services

### Q10. What is a Provider?

**Answer:**
Any class decorated with `@Injectable()` that can be injected via dependency injection. Includes services, repositories, factories, helpers.

```typescript
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly emailService: EmailService,
  ) {}

  async create(dto: CreateUserDto): Promise<User> {
    const hashedPassword = await bcrypt.hash(dto.password, 12);
    const user = this.userRepository.create({ ...dto, password: hashedPassword });
    await this.userRepository.save(user);
    await this.emailService.sendWelcome(user.email);
    return user;
  }
}
```

---

### Q11. What are custom providers?

**Answer:**
Providers with non-class values or factory functions.

```typescript
// Value provider
{ provide: 'APP_CONFIG', useValue: { port: 3000 } }

// Factory provider
{
  provide: DatabaseService,
  useFactory: (config: ConfigService) => new DatabaseService(config.get('DB_URL')),
  inject: [ConfigService],
}

// Class provider (alias)
{ provide: AnimalService, useClass: CatService }

// Inject non-class
@Injectable()
class MyService {
  constructor(@Inject('APP_CONFIG') private config: any) {}
}
```

---

## Dependency Injection

### Q12. How does dependency injection work in NestJS?

**Answer:**
NestJS has a built-in IoC (Inversion of Control) container. When a class is decorated with `@Injectable()` and listed in a module's `providers`, NestJS:
1. Reads constructor parameter types via TypeScript metadata
2. Resolves those types to registered providers
3. Instantiates and injects them automatically

```typescript
@Injectable()
export class OrdersService {
  constructor(
    private usersService: UsersService,   // injected automatically
    private productsService: ProductsService, // injected automatically
  ) {}
}
```

---

### Q13. What is `@InjectRepository`?

**Answer:**
Decorator for injecting TypeORM repositories into services.

```typescript
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}
  
  findAll() {
    return this.userRepository.find();
  }
}
```

Requires `TypeOrmModule.forFeature([User])` in the module's `imports`.

---

## Middleware, Guards, Interceptors, Pipes, Filters

### Q14. What is the NestJS request lifecycle?

**Answer:**
Order of execution for an incoming request:

```
Request
  → Middleware
  → Guards (can reject)
  → Interceptors (before)
  → Pipes (transform/validate)
  → Route Handler
  → Interceptors (after)
  → Exception Filters (if error)
  → Response
```

---

### Q15. What is a Guard?

**Answer:**
Determines if a request should be allowed to proceed. Returns boolean or throws.

```typescript
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}

// Role-based guard
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.get<string[]>('roles', context.getHandler());
    if (!roles) return true;
    
    const { user } = context.switchToHttp().getRequest();
    return roles.includes(user.role);
  }
}

// Usage
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@Delete(':id')
remove(@Param('id') id: string) { ... }
```

---

### Q16. What is an Interceptor?

**Answer:**
Wraps the route handler execution. Can transform responses, add caching, log timing.

```typescript
@Injectable()
export class TransformInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      map(data => ({
        success: true,
        data,
        timestamp: new Date().toISOString(),
      })),
    );
  }
}

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const start = Date.now();
    return next.handle().pipe(
      tap(() => console.log(`Request took ${Date.now() - start}ms`)),
    );
  }
}
```

---

### Q17. What is a Pipe?

**Answer:**
Transforms and validates data before it reaches the route handler.

```typescript
// Built-in pipes
@Param('id', ParseIntPipe) id: number
@Param('uuid', ParseUUIDPipe) id: string
@Body(new ValidationPipe()) body: CreateUserDto

// Custom pipe
@Injectable()
export class PositiveIntPipe implements PipeTransform {
  transform(value: any) {
    const num = parseInt(value);
    if (isNaN(num) || num <= 0) {
      throw new BadRequestException('Value must be a positive integer');
    }
    return num;
  }
}
```

---

### Q18. What is an Exception Filter?

**Answer:**
Catches exceptions thrown during request processing and formats the error response.

```typescript
@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const status = exception.getStatus();

    res.status(status).json({
      success: false,
      statusCode: status,
      message: exception.message,
      timestamp: new Date().toISOString(),
    });
  }
}

// Global exception filter
app.useGlobalFilters(new HttpExceptionFilter());
```

---

### Q19. What is Middleware in NestJS?

**Answer:**
Like Express middleware — runs before guards. Used for logging, request modification, etc.

```typescript
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log(`${req.method} ${req.originalUrl}`);
    next();
  }
}

// Apply in module
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
```

---

## Database with TypeORM and Prisma

### Q20. How do you set up TypeORM in NestJS?

**Answer:**

```typescript
// app.module.ts
TypeOrmModule.forRoot({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: [User, Job, Application],
  synchronize: false, // never true in production
  migrations: ['dist/migrations/*.js'],
  migrationsRun: true,
})

// Entity
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column()
  passwordHash: string;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.USER })
  role: UserRole;

  @CreateDateColumn()
  createdAt: Date;

  @OneToMany(() => Application, app => app.user)
  applications: Application[];
}
```

---

### Q21. How do you set up Prisma in NestJS?

**Answer:**

```typescript
// prisma.service.ts
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}

// Usage in service
@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.user.findMany({
      select: { id: true, email: true, name: true },
    });
  }
}
```

---

## Authentication and Authorization

### Q22. How do you implement JWT auth in NestJS?

**Answer:**

```typescript
// auth.module.ts
@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get('JWT_SECRET'),
        signOptions: { expiresIn: '15m' },
      }),
    }),
  ],
  providers: [AuthService, JwtStrategy],
  controllers: [AuthController],
})
export class AuthModule {}

// jwt.strategy.ts
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.get('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; email: string }) {
    return { userId: payload.sub, email: payload.email };
  }
}
```

---

### Q23. How do you implement role-based access control (RBAC)?

**Answer:**

```typescript
// roles.decorator.ts
export const Roles = (...roles: string[]) => SetMetadata('roles', roles);

// roles.guard.ts
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<string[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!roles) return true;
    const { user } = context.switchToHttp().getRequest();
    return roles.some(role => user.roles?.includes(role));
  }
}

// Usage
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@Delete(':id')
remove(@Param('id') id: string) { ... }
```

---

## Validation and Serialization

### Q24. How does `ValidationPipe` work with DTOs?

**Answer:**

```typescript
// Global setup
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,      // strip unknown properties
  forbidNonWhitelisted: true, // throw if unknown props
  transform: true,      // auto-transform types
}));

// DTO
import { IsEmail, IsString, MinLength, IsOptional } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateUserDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  password: string;

  @IsOptional()
  @IsString()
  @Transform(({ value }) => value?.trim())
  name?: string;
}
```

---

### Q25. How do you exclude fields from responses?

**Answer:**

```typescript
import { Exclude, Expose } from 'class-transformer';

export class UserResponseDto {
  @Expose()
  id: string;

  @Expose()
  email: string;

  @Exclude()
  password: string; // never sent to client
}

// In controller
@UseInterceptors(ClassSerializerInterceptor)
@Get(':id')
async findOne(@Param('id') id: string) {
  const user = await this.usersService.findOne(id);
  return plainToInstance(UserResponseDto, user);
}
```

---

## Testing

### Q26. How do you unit test a NestJS service?

**Answer:**

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

describe('UsersService', () => {
  let service: UsersService;
  let mockRepo: jest.Mocked<Repository<User>>;

  beforeEach(async () => {
    mockRepo = {
      findOne: jest.fn(),
      save: jest.fn(),
      create: jest.fn(),
    } as any;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(User), useValue: mockRepo },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  it('should find a user', async () => {
    mockRepo.findOne.mockResolvedValue({ id: '1', email: 'test@test.com' } as User);
    const user = await service.findOne('1');
    expect(user.email).toBe('test@test.com');
  });
});
```

---

### Q27. How do you e2e test a NestJS app?

**Answer:**

```typescript
import * as request from 'supertest';
import { Test } from '@nestjs/testing';

describe('AuthController (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe());
    await app.init();
  });

  it('POST /auth/login', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'test@test.com', password: 'password123' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('accessToken');
  });

  afterAll(() => app.close());
});
```

---

## Advanced Topics

### Q28. What is the `ConfigModule` in NestJS?

**Answer:**

```typescript
// app.module.ts
ConfigModule.forRoot({
  isGlobal: true,       // available everywhere
  validationSchema: Joi.object({
    DATABASE_URL: Joi.string().required(),
    JWT_SECRET: Joi.string().required(),
  }),
})

// Usage
@Injectable()
export class AppService {
  constructor(private config: ConfigService) {}
  
  getDatabaseUrl() {
    return this.config.get<string>('DATABASE_URL');
  }
}
```

---

### Q29. How do you implement event-driven communication in NestJS?

**Answer:**

```typescript
// EventEmitter2 module
@Injectable()
export class UsersService {
  constructor(private eventEmitter: EventEmitter2) {}

  async create(dto: CreateUserDto) {
    const user = await this.userRepository.save(dto);
    this.eventEmitter.emit('user.created', new UserCreatedEvent(user));
    return user;
  }
}

@Injectable()
export class EmailService {
  @OnEvent('user.created')
  async handleUserCreated(event: UserCreatedEvent) {
    await this.sendWelcomeEmail(event.user.email);
  }
}
```

---

### Q30. How do you implement WebSockets in NestJS?

**Answer:**

```typescript
@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway {
  @WebSocketServer()
  server: Server;

  @SubscribeMessage('sendMessage')
  handleMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() message: string,
  ) {
    this.server.emit('message', { from: client.id, message });
  }

  handleConnection(client: Socket) {
    console.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    console.log(`Client disconnected: ${client.id}`);
  }
}
```

---

### Q31. What is the difference between a Guard and Middleware in NestJS?

**Answer:**

| Feature | Middleware | Guard |
|---------|-----------|-------|
| Execution context | Express request/response | Full NestJS execution context |
| Access to handler metadata | No | Yes (via Reflector) |
| Can use DI | Yes | Yes |
| Use case | Logging, request mutation | Auth, authorization |
| Return value | Calls `next()` | Returns boolean |

Middleware runs before guards in the request lifecycle.

---

### Q32. How do you implement rate limiting in NestJS?

**Answer:**

```typescript
// Install: @nestjs/throttler

// app.module.ts
ThrottlerModule.forRoot({
  ttl: 60,   // time window in seconds
  limit: 10, // max requests per window
})

// Controller
@UseGuards(ThrottlerGuard)
@Controller('auth')
export class AuthController {
  @Throttle(5, 60) // override: 5 requests per 60s
  @Post('login')
  login() { ... }
}
```

---

## Quick Reference

### Decorators

| Decorator | Purpose |
|-----------|---------|
| `@Module()` | Define a module |
| `@Controller()` | Define a controller |
| `@Injectable()` | Mark as injectable provider |
| `@Get/Post/Put/Patch/Delete()` | HTTP method routes |
| `@Param()` | Route parameter |
| `@Body()` | Request body |
| `@Query()` | Query string |
| `@UseGuards()` | Apply guards |
| `@UseInterceptors()` | Apply interceptors |
| `@UsePipes()` | Apply pipes |
| `@UseFilters()` | Apply exception filters |
| `@SetMetadata()` | Attach metadata |
| `@Inject()` | Custom injection token |
