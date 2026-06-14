/* test_fcol.sas - FCOL : colonne courante d un fichier externe (stub) */
data _null_;
  fid = 0;
  c = fcol(fid);
  put 'FCOL(0) = ' c;
run;
