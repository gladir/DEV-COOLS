/* test_foptnum.sas - FOPTNUM : nombre d items d information d un fichier (stub) */
data _null_;
  fid = 0;
  n = foptnum(fid);
  put 'FOPTNUM(0) = ' n;
run;
