/* test_juldate.sas - JULDATE : date julienne depuis une date SAS (stub) */
data _null_;
  jd = juldate(0);
  put 'JULDATE(0) = ' jd;
  jd2 = juldate(365);
  put 'JULDATE(365) = ' jd2;
run;
