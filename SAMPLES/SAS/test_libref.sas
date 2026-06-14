/* test_libref.sas - LIBREF : verifier qu un libref est assigne (stub) */
data _null_;
  rc = libref('WORK');
  put 'LIBREF(WORK) = ' rc;
  rc2 = libref('MYLIB');
  put 'LIBREF(MYLIB) = ' rc2;
run;
