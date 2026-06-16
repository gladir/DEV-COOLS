/* test_modulein.sas - MODULEIN : routine externe IML (retour numerique) */
data _null_;
  n = modulein('MYIML', 'ARG1');
  put 'MODULEIN(MYIML,ARG1) = ' n '  (attendu: 4)';
run;
