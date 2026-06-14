/* test_ktranslate.sas - KTRANSLATE : remplacer des caracteres DBCS (stub) */
data _null_;
  /* KTRANSLATE(str, from, to) */
  s = ktranslate('BONJOUR', 'O', '0');
  put 'KTRANSLATE(BONJOUR,O,0) = ' s;
run;
