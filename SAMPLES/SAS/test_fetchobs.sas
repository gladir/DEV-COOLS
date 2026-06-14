/* test_fetchobs.sas - FETCHOBS : lire une observation par numero (stub) */
data _null_;
  dsid = 0;
  rc = fetchobs(dsid, 1);
  put 'FETCHOBS(0,1) = ' rc;
run;
