/* test_dclose.sas - DCLOSE : fermer un repertoire (stub) */
data _null_;
  did = 0;
  rc = dclose(did);
  put 'DCLOSE(0) = ' rc;
run;
