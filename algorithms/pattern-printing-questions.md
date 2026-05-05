# Pattern Printing Questions

**Purpose:** Star and number printing patterns asked in early-round screens, written tests, and many fresher-to-mid level interviews. Each pattern includes a JavaScript solution, the underlying loop logic, and (where useful) a Python alternative.

> **Why these still matter:** they test loop reasoning, index math, and the ability to translate visual structure into code without a debugger.

---

## Table of Contents

1. [Right Triangle of Stars](#right-triangle-of-stars)
2. [Inverted Right Triangle](#inverted-right-triangle)
3. [Pyramid (Centered Triangle)](#pyramid-centered-triangle)
4. [Inverted Pyramid](#inverted-pyramid)
5. [Diamond](#diamond)
6. [Hollow Square](#hollow-square)
7. [Hollow Triangle](#hollow-triangle)
8. [Hollow Pyramid](#hollow-pyramid)
9. [Number Triangle (1, 12, 123 ...)](#number-triangle-1-12-123)
10. [Floyd's Triangle](#floyds-triangle)
11. [Pascal's Triangle](#pascals-triangle)
12. [Square Pattern (Solid)](#square-pattern-solid)
13. [Cross / X Pattern](#cross--x-pattern)
14. [Butterfly Pattern](#butterfly-pattern)
15. [Hourglass](#hourglass)

---

## Right Triangle of Stars

```
*
* *
* * *
* * * *
* * * * *
```

**JavaScript:**
```javascript
function rightTriangle(n) {
  for (let i = 1; i <= n; i++) {
    console.log('* '.repeat(i).trim());
  }
}
rightTriangle(5);
```

**Python:**
```python
def right_triangle(n):
    for i in range(1, n + 1):
        print('* ' * i)
```

**Logic:** outer loop = row number i (1..n), each row prints i stars.

---

## Inverted Right Triangle

```
* * * * *
* * * *
* * *
* *
*
```

```javascript
function invertedTriangle(n) {
  for (let i = n; i >= 1; i--) {
    console.log('* '.repeat(i).trim());
  }
}
```

**Logic:** count rows down from n to 1.

---

## Pyramid (Centered Triangle)

```
    *
   * *
  * * *
 * * * *
* * * * *
```

```javascript
function pyramid(n) {
  for (let i = 1; i <= n; i++) {
    const spaces = ' '.repeat(n - i);
    const stars  = '* '.repeat(i).trim();
    console.log(spaces + stars);
  }
}
pyramid(5);
```

**Python:**
```python
def pyramid(n):
    for i in range(1, n + 1):
        print(' ' * (n - i) + '* ' * i)
```

**Logic:**
- Leading spaces per row = n − i
- Stars per row = i
- The trailing space after the last star isn't required, but `'* '` keeps the visual triangle aligned.

---

## Inverted Pyramid

```
* * * * *
 * * * *
  * * *
   * *
    *
```

```javascript
function invertedPyramid(n) {
  for (let i = n; i >= 1; i--) {
    console.log(' '.repeat(n - i) + '* '.repeat(i).trim());
  }
}
```

---

## Diamond

```
    *
   * *
  * * *
 * * * *
* * * * *
 * * * *
  * * *
   * *
    *
```

```javascript
function diamond(n) {
  for (let i = 1; i <= n; i++) {
    console.log(' '.repeat(n - i) + '* '.repeat(i).trim());
  }
  for (let i = n - 1; i >= 1; i--) {
    console.log(' '.repeat(n - i) + '* '.repeat(i).trim());
  }
}
diamond(5);
```

**Logic:** print pyramid for upper half, then inverted pyramid (skipping the duplicated middle row).

---

## Hollow Square

```
* * * * *
*       *
*       *
*       *
* * * * *
```

```javascript
function hollowSquare(n) {
  for (let i = 0; i < n; i++) {
    let row = '';
    for (let j = 0; j < n; j++) {
      if (i === 0 || i === n - 1 || j === 0 || j === n - 1) row += '* ';
      else row += '  ';
    }
    console.log(row.trimEnd());
  }
}
hollowSquare(5);
```

**Logic:** print a star only on the border (first/last row or first/last column).

---

## Hollow Triangle

```
*
* *
*   *
*     *
* * * * *
```

```javascript
function hollowTriangle(n) {
  for (let i = 1; i <= n; i++) {
    let row = '';
    for (let j = 1; j <= i; j++) {
      if (i === n || j === 1 || j === i) row += '* ';
      else row += '  ';
    }
    console.log(row.trimEnd());
  }
}
```

---

## Hollow Pyramid

```
    *
   * *
  *   *
 *     *
* * * * *
```

```javascript
function hollowPyramid(n) {
  for (let i = 1; i <= n; i++) {
    let row = ' '.repeat(n - i);
    for (let j = 1; j <= i; j++) {
      if (i === n || j === 1 || j === i) row += '* ';
      else row += '  ';
    }
    console.log(row.trimEnd());
  }
}
hollowPyramid(5);
```

---

## Number Triangle (1, 12, 123 ...)

```
1
1 2
1 2 3
1 2 3 4
1 2 3 4 5
```

```javascript
function numberTriangle(n) {
  for (let i = 1; i <= n; i++) {
    let row = '';
    for (let j = 1; j <= i; j++) row += j + ' ';
    console.log(row.trimEnd());
  }
}
```

**Variant — same number:**
```
1
2 2
3 3 3
```
Replace `j` with `i` in the inner loop.

**Variant — descending:**
```
5 4 3 2 1
4 3 2 1
3 2 1
2 1
1
```
```javascript
for (let i = n; i >= 1; i--) {
  let row = '';
  for (let j = i; j >= 1; j--) row += j + ' ';
  console.log(row.trimEnd());
}
```

---

## Floyd's Triangle

A right triangle of consecutive natural numbers.

```
1
2 3
4 5 6
7 8 9 10
11 12 13 14 15
```

```javascript
function floyd(n) {
  let num = 1;
  for (let i = 1; i <= n; i++) {
    let row = '';
    for (let j = 1; j <= i; j++) row += (num++) + ' ';
    console.log(row.trimEnd());
  }
}
floyd(5);
```

---

## Pascal's Triangle

```
        1
       1 1
      1 2 1
     1 3 3 1
    1 4 6 4 1
```

**Method 1 — using nCr formula:**
```javascript
function pascal(n) {
  for (let i = 0; i < n; i++) {
    let row = ' '.repeat(n - i);
    let val = 1;
    for (let j = 0; j <= i; j++) {
      row += val + ' ';
      val = (val * (i - j)) / (j + 1);
    }
    console.log(row.trimEnd());
  }
}
pascal(5);
```

**Method 2 — building each row from the previous:**
```javascript
function pascal(n) {
  let row = [1];
  for (let i = 0; i < n; i++) {
    console.log(' '.repeat(n - i) + row.join(' '));
    const next = [1];
    for (let j = 0; j < row.length - 1; j++) next.push(row[j] + row[j + 1]);
    next.push(1);
    row = next;
  }
}
```

**Logic recap:** each entry is `C(i, j) = i! / (j! · (i−j)!)`, equivalently `prev[j-1] + prev[j]`.

---

## Square Pattern (Solid)

```
* * * * *
* * * * *
* * * * *
* * * * *
* * * * *
```

```javascript
function square(n) {
  for (let i = 0; i < n; i++) {
    console.log('* '.repeat(n).trim());
  }
}
```

---

## Cross / X Pattern

```
*       *
  *   *
    *
  *   *
*       *
```

```javascript
function cross(n) {
  for (let i = 0; i < n; i++) {
    let row = '';
    for (let j = 0; j < n; j++) {
      if (j === i || j === n - 1 - i) row += '* ';
      else row += '  ';
    }
    console.log(row.trimEnd());
  }
}
cross(5);
```

**Logic:** cell is on the X when its column equals the row index (`j === i`) or its mirror (`j === n - 1 - i`).

---

## Butterfly Pattern

```
*               *
* *           * *
* * *       * * *
* * * *   * * * *
* * * * * * * * * *
* * * * * * * * * *
* * * *   * * * *
* * *       * * *
* *           * *
*               *
```

```javascript
function butterfly(n) {
  // Upper half
  for (let i = 1; i <= n; i++) {
    const stars  = '* '.repeat(i).trim();
    const spaces = '  '.repeat(2 * (n - i));
    console.log(stars + ' ' + spaces + ' ' + stars);
  }
  // Lower half
  for (let i = n; i >= 1; i--) {
    const stars  = '* '.repeat(i).trim();
    const spaces = '  '.repeat(2 * (n - i));
    console.log(stars + ' ' + spaces + ' ' + stars);
  }
}
butterfly(5);
```

**Logic:** each row is two mirrored right-triangles separated by shrinking-then-growing whitespace.

---

## Hourglass

```
* * * * *
 * * * *
  * * *
   * *
    *
   * *
  * * *
 * * * *
* * * * *
```

```javascript
function hourglass(n) {
  for (let i = n; i >= 1; i--) {
    console.log(' '.repeat(n - i) + '* '.repeat(i).trim());
  }
  for (let i = 2; i <= n; i++) {
    console.log(' '.repeat(n - i) + '* '.repeat(i).trim());
  }
}
hourglass(5);
```

---

## Pattern-Solving Methodology

For any pattern problem, follow this template:

1. **Identify rows** — how many rows total? Row index range?
2. **Per-row decomposition**:
   - Leading spaces (count vs. row index)
   - Symbol sequence (count, value)
   - Trailing spaces or symbols (mirror?)
3. **Border vs. interior** — for hollow shapes, decide which `(i, j)` cells print the symbol.
4. **Translate to nested loops** — outer loop = row, inner loops = columns / segments.
5. **Test with n = 1, 2, 3** before scaling up.

| Visual cue | Likely loop structure |
|------------|----------------------|
| Right-aligned shape | leading spaces depend on row |
| Mirror image | print left half, mirror, or use two inner loops |
| Hollow shape | condition on `i === 0 || j === 0 || i === n-1 || j === width-1` |
| Increasing then decreasing | two stacked loops |
| Numbers count up across all rows | outer counter incremented inside inner loop |

---

## Practice Set

- [ ] Right triangle, inverted right triangle
- [ ] Pyramid, inverted pyramid, diamond
- [ ] Hollow square, hollow triangle, hollow pyramid
- [ ] Number triangle (ascending, descending, repeated)
- [ ] Floyd's triangle, Pascal's triangle
- [ ] Cross, butterfly, hourglass
- [ ] Bonus: Sierpinski triangle, spiral matrix
