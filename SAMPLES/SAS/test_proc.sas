/* test_proc.sas - test TODO 17 : ETAPE PROC (PROC STEP) ET INFRASTRUCTURE */

/* Test 1 : PROC PRINT simple */
proc print data=test1;
run;

/* Test 2 : PROC PRINT avec VAR */
proc print data=test1;
  var x y total;
run;

/* Test 3 : PROC MEANS avec options */
proc means data=test1;
  var score note;
run;

/* Test 4 : PROC SORT avec BY */
proc sort data=test1 out=test1_sorted;
  by nom age;
run;

/* Test 5 : PROC FREQ avec TABLES */
proc freq data=test1;
  tables genre;
run;

/* Test 6 : PROC FORMAT (stub) */
proc format;
run;

/* Test 7 : PROC PRINT avec NOPRINT */
proc print data=test1 noprint;
  var x;
run;

/* Test 8 : PROC MEANS avec CLASS et TITLE */
proc means data=test1;
  class genre;
  var score;
  title 'Statistiques par genre';
  footnote 'Source: test_proc.sas';
run;

/* Test 9 : PROC non reconnue */
proc bizarre data=test1;
  var x;
run;

/* Test 10 : PROC avec QUIT au lieu de RUN */
proc print data=test1;
  var x;
quit;
