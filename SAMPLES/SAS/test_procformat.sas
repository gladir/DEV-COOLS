/* test_procformat.sas - test TODO 20 : PROC FORMAT ET FORMATS */

/* Test 1 : PROC FORMAT avec VALUE simple (valeurs uniques) */
proc format;
  value agefmt
    1 = 'Enfant'
    2 = 'Adolescent'
    3 = 'Adulte'
    4 = 'Senior'
  ;
run;

/* Test 2 : PROC FORMAT avec plages numeriques */
proc format;
  value scorefmt
    low - 50 = 'Faible'
    51 - 75 = 'Moyen'
    76 - 100 = 'Bon'
    other = 'Inconnu'
  ;
run;

/* Test 3 : PROC FORMAT avec HIGH */
proc format;
  value tempfmt
    low - 0 = 'Gel'
    1 - 15 = 'Froid'
    16 - 25 = 'Tempere'
    26 - high = 'Chaud'
  ;
run;

/* Test 4 : DATA step avec FORMAT */
data test1;
  age = 3;
  score = 85;
  format age agefmt. score scorefmt.;
run;

/* Test 5 : PROC PRINT avec FORMAT applique */
proc print data=test1;
  var age score;
  format age agefmt.;
run;

/* Test 6 : PROC FORMAT vide */
proc format;
run;

/* Test 7 : FORMAT avec format predefini BEST. (stub) */
data test2;
  x = 42;
  format x best.;
run;

/* Test 8 : PROC FORMAT avec un seul VALUE et OTHER */
proc format;
  value yesno
    0 = 'Non'
    1 = 'Oui'
    other = 'NA'
  ;
run;

/* Test 9 : Utilisation du format dans un DATA step */
data test3;
  reponse = 1;
  format reponse yesno.;
run;
