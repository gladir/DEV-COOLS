/* test_fget.sas - FGET : lire dans le buffer d un fichier externe (stub) */
data _null_;
  fid = 0;
  buf = ' ';
  rc = fget(fid, buf, 80);
  put 'FGET(0,buf,80) = ' rc;
run;
