/* test_libref.sas - LIBREF : verifier qu un libref est assigne */
data _null_;
  rc = libref('WORK');
  put 'LIBREF(WORK) = ' rc '  (attendu: 0)';
  rc2 = libref('MYLIB');
  put 'LIBREF(MYLIB) = ' rc2 '  (attendu: 1)';
  rc3 = libref('');
  put 'LIBREF(vide) = ' rc3 '  (attendu: 1)';
run;
