/* test_finfo.sas - FINFO : information sur un fichier externe (stub) */
data _null_;
  fid = 0;
  info = finfo(fid, 'FILENAME');
  put 'FINFO(0,FILENAME) = ' info;
run;
