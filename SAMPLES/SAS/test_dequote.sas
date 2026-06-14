/* test_dequote.sas - DEQUOTE : retirer guillemets doubles (stub copy) */
data _null_;
  s = 'Hello World';
  r = dequote(s);
  put 'DEQUOTE("Hello World") = ' r;
  t = 'SAS ""language""';
  u = dequote(t);
  put 'DEQUOTE(double) = ' u;
run;
