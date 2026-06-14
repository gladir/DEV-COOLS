/* test_dhms.sas - DHMS : datetime de date, heures, min, sec (stub) */
data _null_;
  /* DHMS(date, heure, minute, seconde) */
  dt = dhms(0, 12, 30, 0);
  put 'DHMS(0,12,30,0) = ' dt;
  dt2 = dhms(365, 0, 0, 0);
  put 'DHMS(365,0,0,0) = ' dt2;
run;
