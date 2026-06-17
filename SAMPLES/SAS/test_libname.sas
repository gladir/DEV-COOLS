/* test_libname.sas - LIBNAME : assigner un libref a une bibliotheque */
data _null_;
  /* LIBNAME(libref, path, engine) */
  rc = libname('MYLIB', '.', 'BASE');
  put 'LIBNAME(MYLIB,.) = ' rc '  (attendu: 0)';
  bad = libname('MYLIB', '__no_such_dir__', 'BASE');
  put 'LIBNAME(absent) = ' bad '  (attendu: 1)';
run;
