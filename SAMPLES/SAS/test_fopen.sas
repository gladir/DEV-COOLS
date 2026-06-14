/* test_fopen.sas - FOPEN : ouvrir un fichier externe (stub) */
data _null_;
  /* FOPEN(fileref, mode) */
  fid = fopen('MYFILE', 'I');
  put 'FOPEN(MYFILE,I) = ' fid;
run;
