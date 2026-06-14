/* test_minute.sas - MINUTE : minutes depuis une valeur time SAS (stub) */
data _null_;
  m = minute(3600);
  put 'MINUTE(3600) = ' m;
  m2 = minute(0);
  put 'MINUTE(0) = ' m2;
run;
