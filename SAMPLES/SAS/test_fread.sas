/* test_fread.sas - FREAD : lire un enregistrement dans le FDB (stub) */
data _null_;
  fid = 0;
  rc = fread(fid);
  put 'FREAD(0) = ' rc;
run;
