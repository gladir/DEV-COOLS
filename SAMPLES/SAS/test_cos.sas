/* test_cos.sas - COS : cosinus */
data _null_;
  /* Backend entier : FCOS puis arrondi entier x87 */
  a = cos(0);
  put 'COS(0) = ' a '  (attendu: 1)';
  b = cos(1);
  put 'COS(1) = ' b '  (attendu: 1)';
  c = cos(-1);
  put 'COS(-1) = ' c '  (attendu: 1)';
run;
