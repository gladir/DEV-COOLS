/* test_modulec.sas - MODULEC : appeler une routine externe (retour chaine) (stub) */
data _null_;
  s = modulec('MYMODULE', 'ARG1');
  put 'MODULEC(MYMODULE,ARG1) = ' s;
run;
