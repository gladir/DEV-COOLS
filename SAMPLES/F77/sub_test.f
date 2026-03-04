C     sub_test.f - Test de l'appel de sous-programme (SUBROUTINE)
C     Testé avec F77C86 - compilateur FORTRAN 77 vers 8086
C
      PROGRAM SUBTEST
      INTEGER N, R
      N = 5
      R = 1
      CALL FACT(N, R)
      PRINT *, R
      END
C
C     Sous-programme : calcul du factoriel N! -> R
C
      SUBROUTINE FACT(N, R)
      INTEGER N, R, I
      R = 1
      DO 10 I = 1, N
      R = R * I
   10 CONTINUE
      RETURN
      END
