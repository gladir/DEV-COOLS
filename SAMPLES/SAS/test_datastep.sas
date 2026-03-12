/* test_datastep.sas - test TODO 16 : ETAPE DATA (DATA STEP) */

/* Test 1 : DATA step simple avec affectations */
data test1;
  x = 10;
  y = 20;
  total = x + y;
  put 'total=' total;
run;

/* Test 2 : DATA step avec OUTPUT explicite */
data test2;
  a = 1;
  output;
  a = 2;
  output;
  put 'a=' a;
run;

/* Test 3 : DATA step avec DELETE conditionnel */
data test3;
  score = 55;
  if score < 60 then delete;
  put 'score=' score;
run;

/* Test 4 : DATA step avec STOP */
data test4;
  i = 0;
  do while (i < 100);
    i = i + 1;
    if i > 5 then stop;
    put 'i=' i;
  end;
run;

/* Test 5 : DATA step avec _NULL_ (pas de dataset de sortie) */
data _null_;
  msg = 42;
  put 'Message:' msg;
run;

/* Test 6 : DATA step avec SET */
data copie;
  set test1;
  put 'copie: x=' x;
run;

/* Test 7 : DATA step avec RETAIN */
data cumul;
  retain somme 0;
  val = 10;
  somme = somme + val;
  put 'somme=' somme;
run;

/* Test 8 : DATA step avec variables automatiques */
data auto;
  x = 99;
  put '_N_= observation numero';
  put 'x=' x;
run;
