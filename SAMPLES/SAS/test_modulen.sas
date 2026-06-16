/* test_modulen.sas - MODULEN : routine externe (retour numerique) */
data _null_;
  n = modulen('MYMODULE', 'ARG1');
  put 'MODULEN(MYMODULE,ARG1) = ' n '  (attendu: 4)';
run;
