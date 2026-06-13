/* test_call_symput.sas - CALL SYMPUT : creer variable macro (stub) */
data _null_;
  valeur = 42;
  nom = 'mavar';
  call symput(nom, valeur);
  put 'CALL SYMPUT : stub OK';
run;
