# NestJS Interview Questions

A pedagogical Q&A guide for backend developers preparing for NestJS interviews. Each question includes a clear explanation and a working code example.

---

## 1. Core Architecture

## Q1. What is NestJS?

**Answer:**

NestJS is a progressive Node.js framework for building scalable server-side applications. It uses TypeScript, embraces decorators, and is heavily inspired by Angular's modular architecture and dependency injection. Under the hood it uses Express by default (Fastify is also supported).

```ts
// main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(3000);
}
bootstrap();
```

## Q2. What is the typical NestJS project structure?

**Answer:**

NestJS organizes code by feature modules. Each feature has a module, controller, service, and DTOs.

```
src/
  app.module.ts
  main.ts
  users/
    users.module.ts
    users.controller.ts
    users.service.ts
    dto/create-user.dto.ts
    entities/user.entity.ts
  auth/
    auth.module.ts
    auth.service.ts
```

```ts
// users.module.ts
import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
```

## Q3. How do you bootstrap a NestJS application?

**Answer:**

`NestFactory.create()` builds the app from the root module. You then apply global pipes, filters, and middleware before listening.

```ts
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
  app.useGlobalFilters(new AllExceptionsFilter());
  app.enableCors();
  app.setGlobalPrefix('api');
  await app.listen(3000);
}
```

## Q4. What is the difference between Nest and Express?

**Answer:**

Express is a minimal framework that gives you a router and middleware. Nest provides structure on top: modules, DI container, decorators, guards, interceptors, pipes, validation, and CLI tooling. Nest can run on top of Express or Fastify.

---

## 2. Modules

## Q5. What is a NestJS Module?

**Answer:**

A module is a class annotated with `@Module()` that groups related controllers, providers, and imports. The root `AppModule` ties everything together.

```ts
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
```

## Q6. What is the difference between `imports`, `providers`, `exports`, and `controllers`?

**Answer:**

| Key         | Purpose                                                |
| ----------- | ------------------------------------------------------ |
| imports     | Other modules whose exports you want to use            |
| controllers | Classes that handle incoming HTTP requests             |
| providers   | Services and other injectables this module instantiates|
| exports     | Providers this module makes available to other modules |

```ts
@Module({
  imports: [AuthModule],          // use AuthService
  controllers: [PostsController],
  providers: [PostsService],
  exports: [PostsService],         // share with other modules
})
export class PostsModule {}
```

## Q7. What is a global module?

**Answer:**

A module marked `@Global()` exposes its providers app-wide without needing to import it in every consumer module. Use sparingly — typically for config or logging.

```ts
@Global()
@Module({
  providers: [ConfigService],
  exports: [ConfigService],
})
export class ConfigModule {}
```

## Q8. What is a dynamic module?

**Answer:**

Dynamic modules are configured at registration time via static methods like `forRoot` or `forFeature`. Useful for libraries that need parameters.

```ts
@Module({})
export class DatabaseModule {
  static forRoot(options: DbOptions): DynamicModule {
    return {
      module: DatabaseModule,
      providers: [{ provide: 'DB_OPTIONS', useValue: options }, DatabaseService],
      exports: [DatabaseService],
    };
  }
}

// Usage
@Module({
  imports: [DatabaseModule.forRoot({ host: 'localhost' })],
})
export class AppModule {}
```

---

## 3. Controllers

## Q9. What is a Controller in NestJS?

**Answer:**

A controller handles incoming HTTP requests and returns responses. Each route is a method decorated with an HTTP verb decorator.

```ts
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  findAll() {
    return this.users.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.users.findOne(+id);
  }

  @Post()
  create(@Body() dto: CreateUserDto) {
    return this.users.create(dto);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateUserDto) {
    return this.users.update(+id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.users.remove(+id);
  }
}
```

## Q10. What are common parameter decorators?

**Answer:**

| Decorator    | Source                |
| ------------ | --------------------- |
| `@Param()`   | Route params          |
| `@Query()`   | Query string          |
| `@Body()`    | Request body          |
| `@Headers()` | HTTP headers          |
| `@Req()`     | Underlying req object |
| `@Res()`     | Underlying res object |

```ts
@Get(':id')
get(
  @Param('id') id: string,
  @Query('lang') lang: string,
  @Headers('authorization') auth: string,
) {
  return { id, lang, auth };
}
```

## Q11. How do you set HTTP status codes?

**Answer:**

Use the `@HttpCode()` decorator or throw an exception.

```ts
@Post()
@HttpCode(201)
create(@Body() dto: CreateUserDto) {
  return this.users.create(dto);
}
```

---

## 4. Providers and Services

## Q12. What is a Provider?

**Answer:**

A provider is any class the Nest DI container can instantiate and inject. Services, repositories, factories, and helpers are all providers.

```ts
@Injectable()
export class UsersService {
  private users: User[] = [];

  findAll() { return this.users; }

  create(data: CreateUserDto) {
    const user = { id: Date.now(), ...data };
    this.users.push(user);
    return user;
  }
}
```

## Q13. What are custom providers?

**Answer:**

You can register a provider as a value, factory, or class to control how it is created.

```ts
@Module({
  providers: [
    { provide: 'API_KEY', useValue: 'secret' },                       // value
    { provide: ConfigService, useClass: ProdConfigService },          // class
    {                                                                  // factory
      provide: 'DB',
      useFactory: async (config: ConfigService) => connect(config.dbUrl),
      inject: [ConfigService],
    },
  ],
})
export class AppModule {}

// Inject by token
constructor(@Inject('API_KEY') private key: string) {}
```

---

## 5. Dependency Injection

## Q14. How does dependency injection work in NestJS?

**Answer:**

Nest has its own IoC container. When you mark a class `@Injectable()` and list it in a module's `providers`, Nest can construct it and inject its declared dependencies via the constructor.

```ts
@Injectable()
export class UsersService {}

@Controller('users')
export class UsersController {
  constructor(private users: UsersService) {} // injected automatically
}
```

## Q15. What is `@InjectRepository`?

**Answer:**

When using TypeORM, `@InjectRepository(Entity)` injects the repository for that entity. The repository is registered automatically by `TypeOrmModule.forFeature`.

```ts
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private repo: Repository<User>,
  ) {}

  findAll() {
    return this.repo.find();
  }
}
```

## Q16. What are injection scopes?

**Answer:**

| Scope       | Lifetime                        |
| ----------- | ------------------------------- |
| DEFAULT     | Singleton (one for the app)     |
| REQUEST     | New instance per HTTP request   |
| TRANSIENT   | New instance per consumer       |

```ts
@Injectable({ scope: Scope.REQUEST })
export class RequestLogger {}
```

Request-scoped providers are slower; use only when needed.

---

## 6. Middleware, Guards, Interceptors, Pipes, Filters

## Q17. What is the request lifecycle in NestJS?

**Answer:**

For every request, Nest runs components in this order:

1. **Middleware** — same as Express middleware
2. **Guards** — decide if the request is allowed
3. **Interceptors (before)** — wrap the handler
4. **Pipes** — transform/validate input
5. **Controller handler** — your code
6. **Interceptors (after)** — transform the response
7. **Exception filters** — if any error was thrown

## Q18. What is a Guard?

**Answer:**

A guard implements `CanActivate` and decides if the current request may proceed. Used for authentication and authorization.

```ts
@Injectable()
export class AuthGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    return Boolean(req.headers.authorization);
  }
}

@Controller('admin')
@UseGuards(AuthGuard)
export class AdminController {}
```

## Q19. What is an Interceptor?

**Answer:**

An interceptor wraps a handler — it can transform the response, log timings, or implement caching.

```ts
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  intercept(ctx: ExecutionContext, next: CallHandler) {
    const start = Date.now();
    return next.handle().pipe(
      tap(() => console.log(`Took ${Date.now() - start}ms`)),
    );
  }
}

@UseInterceptors(LoggingInterceptor)
@Controller('users')
export class UsersController {}
```

## Q20. What is a Pipe?

**Answer:**

A pipe transforms or validates input before it reaches the handler. Built-in pipes include `ValidationPipe`, `ParseIntPipe`, `ParseUUIDPipe`.

```ts
@Get(':id')
findOne(@Param('id', ParseIntPipe) id: number) {
  return this.users.findOne(id);
}

// Custom pipe
@Injectable()
export class TrimPipe implements PipeTransform {
  transform(value: any) {
    if (typeof value === 'string') return value.trim();
    return value;
  }
}
```

## Q21. What is an Exception Filter?

**Answer:**

An exception filter catches thrown exceptions and turns them into HTTP responses.

```ts
@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse();
    const status = exception.getStatus();
    res.status(status).json({
      statusCode: status,
      message: exception.message,
      timestamp: new Date().toISOString(),
    });
  }
}

// Apply globally
app.useGlobalFilters(new HttpExceptionFilter());
```

## Q22. What is Middleware in NestJS?

**Answer:**

Middleware is identical to Express middleware — runs before the rest of the lifecycle. Implement `NestMiddleware` and apply via `MiddlewareConsumer`.

```ts
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log(req.method, req.url);
    next();
  }
}

@Module({})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
```

## Q23. Guard vs Middleware — what is the difference?

**Answer:**

Middleware runs early and has no access to the route context (controller, handler). Guards run later, know which controller/handler will be called, and can use Reflector to read decorator metadata. Use guards for authorization, middleware for cross-cutting setup like logging.

---

## 7. Database with TypeORM and Prisma

## Q24. How do you set up TypeORM in NestJS?

**Answer:**

```ts
// app.module.ts
@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5432,
      username: 'app',
      password: 'secret',
      database: 'shop',
      entities: [User],
      synchronize: false,
    }),
    UsersModule,
  ],
})
export class AppModule {}

// user.entity.ts
@Entity()
export class User {
  @PrimaryGeneratedColumn() id: number;
  @Column() email: string;
  @Column() name: string;
}

// users.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [UsersService],
})
export class UsersModule {}
```

## Q25. How do you set up Prisma in NestJS?

**Answer:**

Wrap PrismaClient in a service and export it from a Prisma module.

```ts
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}

// Usage
@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.user.findMany();
  }
}
```

---

## 8. Authentication and Authorization

## Q26. How do you implement JWT auth in NestJS?

**Answer:**

Use `@nestjs/jwt` and `@nestjs/passport`.

```ts
@Module({
  imports: [
    JwtModule.register({ secret: process.env.JWT_SECRET, signOptions: { expiresIn: '1h' } }),
  ],
  providers: [AuthService, JwtStrategy],
})
export class AuthModule {}

@Injectable()
export class AuthService {
  constructor(private users: UsersService, private jwt: JwtService) {}

  async login(email: string, password: string) {
    const user = await this.users.findByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.password))) {
      throw new UnauthorizedException();
    }
    return { token: this.jwt.sign({ sub: user.id, email: user.email }) };
  }
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.JWT_SECRET,
    });
  }
  validate(payload: any) {
    return { userId: payload.sub, email: payload.email };
  }
}

@UseGuards(AuthGuard('jwt'))
@Get('profile')
profile(@Req() req) { return req.user; }
```

## Q27. How do you implement role-based access control (RBAC)?

**Answer:**

Combine a custom decorator with a guard that reads metadata via `Reflector`.

```ts
export const Roles = (...roles: string[]) => SetMetadata('roles', roles);

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(ctx: ExecutionContext) {
    const required = this.reflector.get<string[]>('roles', ctx.getHandler());
    if (!required) return true;
    const { user } = ctx.switchToHttp().getRequest();
    return required.some((r) => user.roles?.includes(r));
  }
}

@UseGuards(AuthGuard('jwt'), RolesGuard)
@Roles('admin')
@Delete(':id')
remove(@Param('id') id: string) {}
```

---

## 9. Validation and Serialization

## Q28. How does `ValidationPipe` work with DTOs?

**Answer:**

DTOs are TypeScript classes decorated with `class-validator` rules. `ValidationPipe` validates the incoming body against the DTO and returns 400 on failure.

```ts
import { IsEmail, IsString, MinLength } from 'class-validator';

export class CreateUserDto {
  @IsEmail() email: string;
  @IsString() @MinLength(3) name: string;
  @MinLength(8) password: string;
}

// main.ts
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,         // strip unknown props
  forbidNonWhitelisted: true,
  transform: true,         // auto-cast types
}));
```

## Q29. How do you exclude fields from responses?

**Answer:**

Use `class-transformer`'s `@Exclude()` plus `ClassSerializerInterceptor`.

```ts
import { Exclude } from 'class-transformer';

export class User {
  id: number;
  email: string;
  @Exclude() password: string;
}

@UseInterceptors(ClassSerializerInterceptor)
@Controller('users')
export class UsersController {
  @Get(':id')
  async get(@Param('id') id: string) {
    const user = await this.users.findOne(+id);
    return new User(user);
  }
}
```

---

## 10. Testing

## Q30. How do you unit test a NestJS service?

**Answer:**

Use Nest's `Test` utility to build a testing module with mocked dependencies.

```ts
describe('UsersService', () => {
  let service: UsersService;
  const mockRepo = { find: jest.fn(), save: jest.fn() };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(User), useValue: mockRepo },
      ],
    }).compile();

    service = module.get(UsersService);
  });

  it('returns all users', async () => {
    mockRepo.find.mockResolvedValue([{ id: 1 }]);
    const result = await service.findAll();
    expect(result).toEqual([{ id: 1 }]);
  });
});
```

## Q31. How do you e2e test a NestJS app?

**Answer:**

Boot the full app in a test environment and hit it with `supertest`.

```ts
describe('Users (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe());
    await app.init();
  });

  it('GET /users', () =>
    request(app.getHttpServer()).get('/users').expect(200));

  afterAll(() => app.close());
});
```

---

## 11. Advanced Topics

## Q32. What is the `ConfigModule`?

**Answer:**

`@nestjs/config` loads environment variables, validates them, and exposes them via `ConfigService`.

```ts
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: Joi.object({
        PORT: Joi.number().default(3000),
        DATABASE_URL: Joi.string().required(),
      }),
    }),
  ],
})
export class AppModule {}

// Usage
constructor(private config: ConfigService) {}

const port = this.config.get<number>('PORT');
```

## Q33. How do you implement event-driven communication in NestJS?

**Answer:**

Use `@nestjs/event-emitter` for in-process events.

```ts
@Module({ imports: [EventEmitterModule.forRoot()] })
export class AppModule {}

@Injectable()
export class UsersService {
  constructor(private events: EventEmitter2) {}

  create(dto: CreateUserDto) {
    const user = /* ... */;
    this.events.emit('user.created', user);
    return user;
  }
}

@Injectable()
export class WelcomeEmailListener {
  @OnEvent('user.created')
  handle(user: User) {
    // send welcome email
  }
}
```

## Q34. How do you implement WebSockets in NestJS?

**Answer:**

Use `@nestjs/websockets` with the Socket.IO adapter.

```ts
@WebSocketGateway({ cors: true })
export class ChatGateway {
  @WebSocketServer() server: Server;

  @SubscribeMessage('message')
  handleMessage(@MessageBody() data: { text: string }) {
    this.server.emit('message', data.text);
    return { status: 'ok' };
  }
}
```

## Q35. How do you implement rate limiting?

**Answer:**

Use `@nestjs/throttler`.

```ts
@Module({
  imports: [
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 10 }]),
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}

// Override per route
@Throttle({ default: { ttl: 60_000, limit: 3 } })
@Post('login')
login() {}
```

## Q36. How do you handle background jobs?

**Answer:**

Use `@nestjs/bull` (Redis-backed queues).

```ts
@Module({
  imports: [
    BullModule.forRoot({ redis: { host: 'localhost', port: 6379 } }),
    BullModule.registerQueue({ name: 'email' }),
  ],
})
export class AppModule {}

@Injectable()
export class EmailService {
  constructor(@InjectQueue('email') private queue: Queue) {}
  async send(to: string) {
    await this.queue.add('send', { to });
  }
}

@Processor('email')
export class EmailProcessor {
  @Process('send')
  handle(job: Job<{ to: string }>) {
    // actually send the email
  }
}
```

## Q37. How do you generate OpenAPI/Swagger docs?

**Answer:**

Use `@nestjs/swagger`.

```ts
const config = new DocumentBuilder()
  .setTitle('My API')
  .setVersion('1.0')
  .addBearerAuth()
  .build();
const document = SwaggerModule.createDocument(app, config);
SwaggerModule.setup('docs', app, document);
```

DTOs document themselves via decorators:

```ts
export class CreateUserDto {
  @ApiProperty() @IsEmail() email: string;
  @ApiProperty({ minLength: 3 }) @IsString() name: string;
}
```

## Q38. What are lifecycle hooks?

**Answer:**

Modules and providers can implement hooks to run code at key points.

| Hook                | When                                |
| ------------------- | ----------------------------------- |
| `onModuleInit`      | After deps are resolved             |
| `onApplicationBootstrap` | After all modules are initialized |
| `onModuleDestroy`   | Before shutdown                     |
| `onApplicationShutdown` | On signal (SIGTERM, etc.)       |

```ts
@Injectable()
export class CacheService implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() { await this.connect(); }
  async onModuleDestroy() { await this.disconnect(); }
}

// Enable shutdown signals
app.enableShutdownHooks();
```

## Q39. What are circular dependencies and how do you fix them?

**Answer:**

When module A imports B and B imports A, Nest cannot resolve construction order. Use `forwardRef()`.

```ts
@Module({
  imports: [forwardRef(() => UsersModule)],
})
export class AuthModule {}

@Injectable()
export class AuthService {
  constructor(
    @Inject(forwardRef(() => UsersService))
    private users: UsersService,
  ) {}
}
```

## Q40. What is the `Reflector` class?

**Answer:**

`Reflector` reads metadata set by decorators (`SetMetadata`, custom decorators). Used in guards and interceptors to inspect handler-level config.

```ts
@Injectable()
export class RolesGuard {
  constructor(private reflector: Reflector) {}
  canActivate(ctx: ExecutionContext) {
    const roles = this.reflector.get<string[]>('roles', ctx.getHandler());
    return /* ... */;
  }
}
```

---

## 12. Quick Reference

### Useful Decorators

| Decorator        | Purpose                          |
| ---------------- | -------------------------------- |
| `@Controller()`  | Register a controller            |
| `@Module()`      | Define a module                  |
| `@Injectable()`  | Mark a class as a provider       |
| `@Get/@Post/...` | Route methods                    |
| `@Param/@Query/@Body` | Parameter binding           |
| `@UseGuards()`   | Attach guard(s)                  |
| `@UseInterceptors()` | Attach interceptor(s)        |
| `@UsePipes()`    | Attach pipe(s)                   |
| `@UseFilters()`  | Attach exception filter(s)       |
| `@SetMetadata()` | Attach metadata for Reflector    |

### Common Packages

| Package                | Purpose                         |
| ---------------------- | ------------------------------- |
| @nestjs/typeorm        | TypeORM integration             |
| @nestjs/jwt            | JWT signing                     |
| @nestjs/passport       | Passport strategies             |
| @nestjs/config         | Env config                      |
| @nestjs/swagger        | OpenAPI docs                    |
| @nestjs/throttler      | Rate limiting                   |
| @nestjs/bull           | Background queues               |
| @nestjs/event-emitter  | In-process events               |
| @nestjs/websockets     | WebSocket gateways              |
| class-validator        | DTO validation                  |
| class-transformer      | DTO serialization               |
