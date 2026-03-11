/* test_procfreqsort.sas - test TODO 19 : PROC FREQ ET PROC SORT */

/* Creer un dataset de test */
data scores;
  x = 42;
  y = 10;
run;

/* Test 1 : PROC FREQ simple avec TABLES */
proc freq data=scores;
  tables x;
run;

/* Test 2 : PROC FREQ avec plusieurs variables TABLES */
proc freq data=scores;
  tables x y;
run;

/* Test 3 : PROC SORT avec BY ascendant */
proc sort data=scores out=scores_sorted;
  by x;
run;

/* Test 4 : PROC SORT avec BY DESCENDING */
proc sort data=scores;
  by descending y;
run;

/* Test 5 : PROC SORT avec plusieurs cles dont une DESCENDING */
proc sort data=scores out=resultat;
  by x descending y;
run;

/* Test 6 : PROC FREQ avec NOPRINT */
proc freq data=scores noprint;
  tables x;
run;

/* Test 7 : PROC FREQ sans TABLES (aucune variable) */
proc freq data=scores;
run;

/* Test 8 : PROC SORT sans BY (avertissement) */
proc sort data=scores;
run;
