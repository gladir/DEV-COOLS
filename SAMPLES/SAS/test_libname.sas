/* test_libname.sas - LIBNAME : assigner un libref a une bibliotheque (stub) */
data _null_;
  /* LIBNAME(libref, path, engine) */
  rc = libname('MYLIB', 'C:\DATA', 'BASE');
  put 'LIBNAME(MYLIB,...) = ' rc;
run;
