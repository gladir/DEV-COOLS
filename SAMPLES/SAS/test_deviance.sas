/* test_deviance.sas - DEVIANCE : calcul de la deviance */
data _null_;
  a = deviance(0, 5, 2);
  put 'DEVIANCE(0,5,2) = ' a '  (attendu: 9)';
  b = deviance(1, 5, 2);
  put 'DEVIANCE(1,5,2) = ' b '  (attendu: 6)';
run;
