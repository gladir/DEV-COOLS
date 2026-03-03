      * Programme COBOL de test - tokeniseur
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HELLO.
       AUTHOR. SYLVAIN MALTAIS.
      *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
           01 WS-NOM          PIC X(20) VALUE 'MONDE'.
           01 WS-COMPTEUR     PIC 9(3)  VALUE 0.
           01 WS-TOTAL        PIC 9V99  VALUE 0.00.
           88 FINI            VALUE 10.
      *
       PROCEDURE DIVISION.
       DEBUT.
           DISPLAY 'BONJOUR ' WS-NOM.
           MOVE 1 TO WS-COMPTEUR.
           ADD 5 TO WS-COMPTEUR.
           COMPUTE WS-TOTAL = WS-COMPTEUR * 2.5.
           IF WS-COMPTEUR > 3
              DISPLAY 'COMPTEUR SUPERIEUR A 3'
           ELSE
              DISPLAY 'COMPTEUR INFERIEUR OU EGAL A 3'
           END-IF.
           STOP RUN.
