/* test_dopen.sas - DOPEN : ouvrir un repertoire (stub) */
data _null_;
  dir = '.';
  did = dopen(dir);
  put 'DOPEN(".") = ' did;
run;
