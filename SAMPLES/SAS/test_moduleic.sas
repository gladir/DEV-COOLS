/* test_moduleic.sas - MODULEIC : routine externe IML (retour chaine) */
data _null_;
  s = moduleic('MYIML', 'ARG1');
  put 'MODULEIC(MYIML,ARG1) = ' s '  (attendu: ARG1)';
run;
