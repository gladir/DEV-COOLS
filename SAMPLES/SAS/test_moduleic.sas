/* test_moduleic.sas - MODULEIC : routine externe IML (retour chaine) (stub) */
data _null_;
  s = moduleic('MYIML', 'ARG1');
  put 'MODULEIC(MYIML,ARG1) = ' s;
run;
