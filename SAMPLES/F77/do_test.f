C     do_test.f - Test de la boucle DO
C     Testé avec F77C86 - compilateur FORTRAN 77 vers 8086
C
      PROGRAM DOTEST
      INTEGER I
      DO 10 I = 1, 5
      PRINT *, I
   10 CONTINUE
      END
