C     arith.f - Test des operations arithmetiques entieres
C     Testé avec F77C86 - compilateur FORTRAN 77 vers 8086
C
      PROGRAM ARITH
      INTEGER A, B, C
      A = 10
      B = 3
      PRINT *, A
      PRINT *, B
      C = A + B
      PRINT *, C
      C = A - B
      PRINT *, C
      C = A * B
      PRINT *, C
      END
