/* test_cos.sas - COS : cosinus (stub) */
data _null_;
  /* COS(0) = 1 (stub retourne 0) */
  a = cos(0);
  put 'COS(0) = ' a;
  /* COS(1) environ 0.54 (stub=0) */
  b = cos(1);
  put 'COS(1) = ' b;
  /* COS(-1) environ 0.54 (stub=0) */
  c = cos(-1);
  put 'COS(-1) = ' c;
run;
