       IDENTIFICATION DIVISION.
       PROGRAM-ID. DATA-TEST.
      *
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EMPLOYES-FILE ASSIGN TO 'EMPLOYES.DAT'
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL.
      *
       DATA DIVISION.
       FILE SECTION.
       FD  EMPLOYES-FILE
           LABEL RECORD IS STANDARD
           RECORD CONTAINS 80 CHARACTERS.
       01  EMP-RECORD.
           05  EMP-NUMERO     PIC 9(6).
           05  EMP-NOM        PIC X(30).
           05  EMP-PRENOM     PIC X(20).
           05  EMP-SALAIRE    PIC 9(7)V99    USAGE COMP-3.
           05  EMP-STATUT     PIC X.
               88  STATUT-ACTIF   VALUE 'A'.
               88  STATUT-INACTIF VALUE 'I'.
      *
       WORKING-STORAGE SECTION.
       01  WS-COMPTEUR        PIC 9(5) VALUE 0.
       01  WS-TOTAL-SALAIRES  PIC 9(9)V99 COMP-3.
       01  WS-FLAGS.
           05  WS-EOF         PIC 9 VALUE 0.
               88  WS-FIN-FICHIER VALUE 1.
           05  WS-ERREUR      PIC 9 VALUE 0.
       01  WS-DATE.
           05  WS-ANNEE       PIC 9(4).
           05  WS-MOIS        PIC 99.
           05  WS-JOUR        PIC 99.
       01  WS-TABLE OCCURS 10 TIMES.
           05  WS-ITEM        PIC X(20).
      *
       PROCEDURE DIVISION.
       DEBUT.
           STOP RUN.
