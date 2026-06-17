/* test_irr.sas - IRR : taux interne de retour minimal */
data _null_;
  r = irr(0);
  put 'IRR(0) = ' r '  (attendu: 0)';
  i = irr(-1000);
  put 'IRR(-1000) = ' i '  (attendu: 10)';
run;
