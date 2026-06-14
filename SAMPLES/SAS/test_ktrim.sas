/* test_ktrim.sas - KTRIM : supprimer espaces DBCS en debut et fin (stub) */
data _null_;
  s = ktrim('  BONJOUR  ');
  put 'KTRIM(  BONJOUR  ) = ' s;
run;
