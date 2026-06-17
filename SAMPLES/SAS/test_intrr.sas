/* test_intrr.sas - INTRR : taux interne de retour minimal */
data _null_;
  r = intrr(0);
  put 'INTRR(0) = ' r '  (attendu: 0)';
  i = intrr(-1000);
  put 'INTRR(-1000) = ' i '  (attendu: 10)';
run;
