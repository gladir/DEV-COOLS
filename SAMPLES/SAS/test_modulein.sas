/* test_modulein.sas - MODULEIN : routine externe IML (retour numerique) (stub) */
data _null_;
  n = modulein('MYIML', 'ARG1');
  put 'MODULEIN(MYIML,ARG1) = ' n;
run;
