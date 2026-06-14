/* test_kreverse.sas - KREVERSE : inverser une chaine DBCS (stub) */
data _null_;
  s = kreverse('BONJOUR');
  put 'KREVERSE(BONJOUR) = ' s;
run;
