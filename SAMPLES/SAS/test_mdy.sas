/* test_mdy.sas - MDY : date SAS depuis mois, jour, annee (stub) */
data _null_;
  d = mdy(1, 1, 2000);
  put 'MDY(1,1,2000) = ' d;
  d2 = mdy(12, 31, 1999);
  put 'MDY(12,31,1999) = ' d2;
run;
