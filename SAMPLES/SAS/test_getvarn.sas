/* test_getvarn.sas - GETVARN : valeur d une variable numerique d un dataset (stub) */
data _null_;
  dsid = 0;
  val = getvarn(dsid, 1);
  put 'GETVARN(0,1) = ' val;
run;
