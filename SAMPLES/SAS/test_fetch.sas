/* test_fetch.sas - FETCH : lire une observation (stub) */
data _null_;
  dsid = 0;
  rc = fetch(dsid);
  put 'FETCH(0) = ' rc;
run;
