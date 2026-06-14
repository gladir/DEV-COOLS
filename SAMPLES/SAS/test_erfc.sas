/* test_erfc.sas - ERFC : complement de la fonction erreur (stub) */
data _null_;
  a = erfc(0);
  put 'ERFC(0) = ' a;
  b = erfc(1);
  put 'ERFC(1) = ' b;
run;
