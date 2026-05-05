# Pattern Printing Questions

A pedagogical Q&A guide for star and number printing patterns commonly asked in early-round technical screens. Each problem includes the expected output, the loop logic explained, and a working code example.

---

## Q1. Print a right triangle of stars.

**Answer:**

```
*
* *
* * *
* * * *
* * * * *
```

The outer loop runs from 1 to n. Each row prints `i` stars.

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

---

## Q2. Print an inverted right triangle of stars.

**Answer:**

```
* * * * *
* * * *
* * *
* *
*
```

Count rows from n down to 1.

```javascript
function invertedTriangle(n) {
  for (let i = n; i >= 1; i--) {
    console.log('* '.repeat(i).trim());
  }
}
invertedTriangle(5);
```

---

## Q3. Print a centered pyramid.

**Answer:**

```
    *
   * *
  * * *
 * * * *
* * * * *
```

Each row has `n - i` leading spaces and `i` stars.

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

---

## Q4. Print an inverted pyramid.

**Answer:**

```
* * * * *
 * * * *
  * * *
   * *
    *
```

Run i from n down to 1, with `n - i` leading spaces.

```javascript
function invertedPyramid(n) {
  for (let i = n; i >= 1; i--) {
    console.log(' '.repeat(n - i) + '* '.repeat(i).trim());
  }
}
invertedPyramid(5);
```

---

## Q5. Print a diamond.

**Answer:**

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

Print a pyramid for the upper half, then an inverted pyramid for the lower half.

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

---

## Q6. Print a hollow square.

**Answer:**

```
* * * * *
*       *
*       *
*       *
* * * * *
```

Print a star only on the border (first/last row or first/last column).

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

---

## Q7. Print a hollow triangle.

**Answer:**

```
*
* *
*   *
*     *
* * * * *
```

Print only the borders: first column, the diagonal (`j === i`), and the last row.

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
hollowTriangle(5);
```

---

## Q8. Print a hollow pyramid.

**Answer:**

```
    *
   * *
  *   *
 *     *
* * * * *
```

Same border logic as the hollow triangle, with leading spaces for the centered shape.

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

## Q9. Print a number triangle (1, 12, 123 ...).

**Answer:**

```
1
1 2
1 2 3
1 2 3 4
1 2 3 4 5
```

Inner loop prints `j` from 1 to `i`.

```javascript
function numberTriangle(n) {
  for (let i = 1; i <= n; i++) {
    let row = '';
    for (let j = 1; j <= i; j++) row += j + ' ';
    console.log(row.trimEnd());
  }
}
numberTriangle(5);
```

---

## Q10. Print the same number on each row (1, 22, 333...).

**Answer:**

```
1
2 2
3 3 3
4 4 4 4
5 5 5 5 5
```

The inner loop prints `i` instead of `j`.

```javascript
function sameNumber(n) {
  for (let i = 1; i <= n; i++) {
    let row = '';
    for (let j = 1; j <= i; j++) row += i + ' ';
    console.log(row.trimEnd());
  }
}
sameNumber(5);
```

---

## Q11. Print a descending number triangle.

**Answer:**

```
5 4 3 2 1
4 3 2 1
3 2 1
2 1
1
```

```javascript
function descendingTriangle(n) {
  for (let i = n; i >= 1; i--) {
    let row = '';
    for (let j = i; j >= 1; j--) row += j + ' ';
    console.log(row.trimEnd());
  }
}
descendingTriangle(5);
```

---

## Q12. Print Floyd's triangle.

**Answer:**

A right triangle of consecutive natural numbers.

```
1
2 3
4 5 6
7 8 9 10
11 12 13 14 15
```

Maintain a single running counter across all rows.

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

## Q13. Print Pascal's triangle.

**Answer:**

```
        1
       1 1
      1 2 1
     1 3 3 1
    1 4 6 4 1
```

Each entry is `C(i, j)`. Two common approaches: use the binomial formula, or build each row from the previous one.

```javascript
// Method 1 — binomial coefficient formula
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

```javascript
// Method 2 — build each row from the previous
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
pascal(5);
```

---

## Q14. Print a solid square.

**Answer:**

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
square(5);
```

---

## Q15. Print a cross (X) pattern.

**Answer:**

```
*       *
  *   *
    *
  *   *
*       *
```

Print a star where `j === i` (main diagonal) or `j === n - 1 - i` (anti-diagonal).

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

---

## Q16. Print a butterfly pattern.

**Answer:**

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

Each row has `i` stars, then `2 * (n - i)` spaces, then `i` stars again. Print the upper half, then the lower half in reverse.

```javascript
function butterfly(n) {
  for (let i = 1; i <= n; i++) {
    const stars = '* '.repeat(i).trim();
    const spaces = ' '.repeat((n - i) * 4);
    console.log(stars + spaces + stars);
  }
  for (let i = n; i >= 1; i--) {
    const stars = '* '.repeat(i).trim();
    const spaces = ' '.repeat((n - i) * 4);
    console.log(stars + spaces + stars);
  }
}
butterfly(5);
```

---

## Q17. Print an hourglass.

**Answer:**

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

Inverted pyramid stacked over a regular pyramid (no duplicate middle row).

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

## Q18. Print an alphabet triangle.

**Answer:**

```
A
A B
A B C
A B C D
A B C D E
```

Use `String.fromCharCode` with offset from `'A'`.

```javascript
function alphabetTriangle(n) {
  for (let i = 1; i <= n; i++) {
    let row = '';
    for (let j = 0; j < i; j++) {
      row += String.fromCharCode(65 + j) + ' ';
    }
    console.log(row.trimEnd());
  }
}
alphabetTriangle(5);
```

---

## Q19. Print a binary number triangle (alternating 1s and 0s).

**Answer:**

```
1
0 1
1 0 1
0 1 0 1
1 0 1 0 1
```

The cell value is `(i + j) % 2`.

```javascript
function binaryTriangle(n) {
  for (let i = 0; i < n; i++) {
    let row = '';
    for (let j = 0; j <= i; j++) {
      row += ((i + j) % 2) + ' ';
    }
    console.log(row.trimEnd());
  }
}
binaryTriangle(5);
```

---

## Q20. Print a right-aligned number pyramid.

**Answer:**

```
        1
      1 2
    1 2 3
  1 2 3 4
1 2 3 4 5
```

```javascript
function rightAlignedNumbers(n) {
  for (let i = 1; i <= n; i++) {
    let row = '  '.repeat(n - i);
    for (let j = 1; j <= i; j++) row += j + ' ';
    console.log(row.trimEnd());
  }
}
rightAlignedNumbers(5);
```

---

## Q21. Print a centered alphabet pyramid.

**Answer:**

```
    A
   A B
  A B C
 A B C D
A B C D E
```

```javascript
function alphabetPyramid(n) {
  for (let i = 1; i <= n; i++) {
    let row = ' '.repeat(n - i);
    for (let j = 0; j < i; j++) {
      row += String.fromCharCode(65 + j) + ' ';
    }
    console.log(row.trimEnd());
  }
}
alphabetPyramid(5);
```

---

## Q22. Print a mirrored right triangle.

**Answer:**

```
        *
      * *
    * * *
  * * * *
* * * * *
```

Right-justified by adding `2 * (n - i)` leading spaces.

```javascript
function mirroredTriangle(n) {
  for (let i = 1; i <= n; i++) {
    console.log(' '.repeat(2 * (n - i)) + '* '.repeat(i).trim());
  }
}
mirroredTriangle(5);
```

---

## Q23. Print a rhombus (parallelogram) pattern.

**Answer:**

```
    * * * * *
   * * * * *
  * * * * *
 * * * * *
* * * * *
```

Each row has `n - i` leading spaces and `n` stars.

```javascript
function rhombus(n) {
  for (let i = 1; i <= n; i++) {
    console.log(' '.repeat(n - i) + '* '.repeat(n).trim());
  }
}
rhombus(5);
```

---

## Q24. Print a hollow diamond.

**Answer:**

```
    *
   * *
  *   *
 *     *
*       *
 *     *
  *   *
   * *
    *
```

Combine hollow pyramid and inverted hollow pyramid.

```javascript
function hollowDiamond(n) {
  for (let i = 1; i <= n; i++) {
    let row = ' '.repeat(n - i);
    for (let j = 1; j <= i; j++) {
      if (j === 1 || j === i) row += '* ';
      else row += '  ';
    }
    console.log(row.trimEnd());
  }
  for (let i = n - 1; i >= 1; i--) {
    let row = ' '.repeat(n - i);
    for (let j = 1; j <= i; j++) {
      if (j === 1 || j === i) row += '* ';
      else row += '  ';
    }
    console.log(row.trimEnd());
  }
}
hollowDiamond(5);
```

---

## Q25. Print a number diamond.

**Answer:**

```
    1
   1 2
  1 2 3
 1 2 3 4
1 2 3 4 5
 1 2 3 4
  1 2 3
   1 2
    1
```

```javascript
function numberDiamond(n) {
  for (let i = 1; i <= n; i++) {
    let row = ' '.repeat(n - i);
    for (let j = 1; j <= i; j++) row += j + ' ';
    console.log(row.trimEnd());
  }
  for (let i = n - 1; i >= 1; i--) {
    let row = ' '.repeat(n - i);
    for (let j = 1; j <= i; j++) row += j + ' ';
    console.log(row.trimEnd());
  }
}
numberDiamond(5);
```

---

## Q26. Print a checkerboard pattern.

**Answer:**

```
* . * . *
. * . * .
* . * . *
. * . * .
* . * . *
```

Use `(i + j) % 2` to alternate characters.

```javascript
function checkerboard(n) {
  for (let i = 0; i < n; i++) {
    let row = '';
    for (let j = 0; j < n; j++) {
      row += ((i + j) % 2 === 0 ? '*' : '.') + ' ';
    }
    console.log(row.trimEnd());
  }
}
checkerboard(5);
```

---

## Q27. Print a Christmas tree.

**Answer:**

```
    *
   * *
  * * *
   * *
    *
```

Combine pyramid and inverted pyramid; or, more decoratively, multiple pyramid layers stacked.

```javascript
function christmasTree(layers) {
  let height = 1;
  for (let layer = 1; layer <= layers; layer++) {
    for (let i = 1; i <= height + layer; i++) {
      console.log(' '.repeat(layers + height - i) + '* '.repeat(i).trim());
    }
    height++;
  }
  // trunk
  console.log(' '.repeat(layers + height - 2) + '*');
}
christmasTree(3);
```

---

## Q28. General methodology — how to solve any pattern.

**Answer:**

For any pattern problem, follow this template:

1. **Identify rows** — how many total? What is the row index range?
2. **Per-row decomposition**:
   - Leading spaces (count vs row index)
   - Symbol sequence (count, value)
   - Trailing spaces or symbols (mirror?)
3. **Border vs interior** — for hollow shapes, decide which `(i, j)` cells print the symbol.
4. **Translate to nested loops** — outer loop = row, inner loops = columns / segments.
5. **Test with n = 1, 2, 3** before scaling up.

| Visual cue | Likely loop structure |
|------------|----------------------|
| Right-aligned shape | leading spaces depend on row |
| Mirror image | print left half, mirror, or use two inner loops |
| Hollow shape | condition on `j === 0 \|\| j === width - 1` |
| Increasing then decreasing | two stacked loops |
| Numbers count up across all rows | running counter incremented inside inner loop |
