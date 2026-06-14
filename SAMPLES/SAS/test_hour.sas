/* test_hour.sas - HOUR : heure depuis une valeur time ou datetime SAS (stub) */
data _null_;
  /* HOUR(time) */
  h = hour(34200);
  put 'HOUR(34200) = ' h;
  h2 = hour(0);
  put 'HOUR(0) = ' h2;
run;
