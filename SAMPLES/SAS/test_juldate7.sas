/* test_juldate7.sas - JULDATE7 : date julienne sur 7 chiffres (stub) */
data _null_;
  jd = juldate7(0);
  put 'JULDATE7(0) = ' jd;
  jd2 = juldate7(365);
  put 'JULDATE7(365) = ' jd2;
run;
