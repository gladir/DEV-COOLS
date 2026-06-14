/* test_hms.sas - HMS : heure SAS depuis heure, minutes, secondes (stub) */
data _null_;
  /* HMS(h, m, s) */
  t = hms(9, 30, 0);
  put 'HMS(9,30,0) = ' t;
  t2 = hms(14, 45, 30);
  put 'HMS(14,45,30) = ' t2;
run;
