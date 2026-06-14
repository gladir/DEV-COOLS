/* test_modulen.sas - MODULEN : routine externe (retour numerique) (stub) */
data _null_;
  n = modulen('MYMODULE', 'ARG1');
  put 'MODULEN(MYMODULE,ARG1) = ' n;
run;
