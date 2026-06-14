/* test_close.sas - CLOSE : fermer un dataset (stub) */
data _null_;
  dsid = 0;
  rc = close(dsid);
  put 'CLOSE(0) = ' rc;
run;
