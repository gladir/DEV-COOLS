/* test_getvarn.sas - GETVARN : valeur d une variable numerique d un dataset */
data _null_;
  dsid = 0;
  val = getvarn(dsid, 1);
  put 'GETVARN(0,1) = ' val '  (attendu: 0)';
  ok = getvarn(1, 3);
  put 'GETVARN(1,3) = ' ok '  (attendu: 3)';
run;
