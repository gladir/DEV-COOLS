/* test_kleft.sas - KLEFT : alignement gauche DBCS (stub) */
data _null_;
  s = kleft('   BONJOUR');
  put 'KLEFT(   BONJOUR) = ' s;
run;
