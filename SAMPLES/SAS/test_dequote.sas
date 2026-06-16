/* test_dequote.sas - DEQUOTE : retirer guillemets externes */
data _null_;
  s = '"Hello World"';
  r = dequote(s);
  put 'DEQUOTE("Hello World") = [' r ']  (attendu: Hello World)';
  t = 'SAS language';
  u = dequote(t);
  put 'DEQUOTE(no quotes) = [' u ']  (attendu: SAS language)';
run;
