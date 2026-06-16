/* test_modulec.sas - MODULEC : appeler une routine externe (retour chaine) */
data _null_;
  s = modulec('MYMODULE', 'ARG1');
  put 'MODULEC(MYMODULE,ARG1) = ' s '  (attendu: ARG1)';
run;
