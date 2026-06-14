/* test_frewind.sas - FREWIND : rembobiner un fichier au debut (stub) */
data _null_;
  fid = 0;
  rc = frewind(fid);
  put 'FREWIND(0) = ' rc;
run;
