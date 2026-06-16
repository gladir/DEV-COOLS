/* test_dopen.sas - DOPEN : ouvrir un repertoire */
data _null_;
  dir = '.';
  did = dopen(dir);
  put 'DOPEN(".") = ' did '  (attendu: 1)';
  bad = dopen('__no_such_dir__');
  put 'DOPEN(absent) = ' bad '  (attendu: 0)';
run;
