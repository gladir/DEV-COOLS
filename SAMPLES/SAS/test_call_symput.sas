/* test_call_symput.sas - CALL SYMPUT : creer variable macro runtime */
data _null_;
  valeur = 42;
  nom = 'mavar';
  call symput(nom, valeur);
  lu = symget('mavar');
  put 'CALL SYMPUT/SYMGET mavar=' lu '  (attendu: 42)';
run;
