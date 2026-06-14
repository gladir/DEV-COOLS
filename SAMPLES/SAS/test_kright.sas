/* test_kright.sas - KRIGHT : alignement a droite DBCS (stub) */
data _null_;
  s = kright('BONJOUR   ');
  put 'KRIGHT(BONJOUR   ) = ' s;
run;
