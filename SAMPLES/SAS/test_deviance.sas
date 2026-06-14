/* test_deviance.sas - DEVIANCE : calcul de la deviance (stub) */
data _null_;
  a = deviance(0, 5, 2);
  put 'DEVIANCE(0,5,2) = ' a;
run;
