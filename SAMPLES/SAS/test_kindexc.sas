/* test_kindexc.sas - KINDEXC : position du premier caractere specifique DBCS (stub) */
data _null_;
  pos = kindexc('BONJOUR', 'AEIOU');
  put 'KINDEXC(BONJOUR, voyelles) = ' pos;
run;
