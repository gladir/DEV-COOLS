/* test_proc.sas - test TODO 17-18 : PROC STEP ET PROC PRINT/MEANS */

/* Test 1 : DATA step puis PROC PRINT simple */
data test1;
  x = 10;
  y = 20;
  total = x + y;
run;

proc print data=test1;
run;

/* Test 2 : PROC PRINT avec VAR */
proc print data=test1;
  var x y total;
run;

/* Test 3 : PROC MEANS avec options */
proc means data=test1;
  var x y;
run;

/* Test 4 : PROC SORT avec BY */
proc sort data=test1 out=test1_sorted;
  by x;
run;

/* Test 5 : PROC FREQ avec TABLES */
proc freq data=test1;
  tables x;
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
  var x;
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

/* Test 11 : PROC MEANS avec stats specifiques */
proc means data=test1 n min max sum;
  var x y;
run;
