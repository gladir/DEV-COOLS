/* test_fput.sas - FPUT : copier des données dans le FDB (stub) */
data _null_;
  fid = 0;
  rc = fput(fid, 'test');
  put 'FPUT(0,test) = ' rc;
run;
