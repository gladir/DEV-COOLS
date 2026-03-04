C     fibo.f - Calcul des N premiers nombres de Fibonacci (iteratif)
C     Testé avec F77C86 - compilateur FORTRAN 77 vers 8086
C
      PROGRAM FIBO
      INTEGER I, N, F
      N = 10
      DO 10 I = 1, N
      CALL FIBONACCI(I, F)
      PRINT *, F
   10 CONTINUE
      END
C
C     Sous-programme : calcul du I-ieme nombre de Fibonacci
C     F(1)=1, F(2)=1, F(N)=F(N-1)+F(N-2)
C
      SUBROUTINE FIBONACCI(N, F)
      INTEGER N, F, A, B, C, I
      A = 1
      B = 1
      IF (N .LE. 1) GOTO 20
      DO 10 I = 3, N
      C = A + B
      A = B
      B = C
   10 CONTINUE
   20 F = B
      RETURN
      END
