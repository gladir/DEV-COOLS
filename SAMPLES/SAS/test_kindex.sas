/* test_kindex.sas - KINDEX : position d une sous-chaine DBCS (stub) */
data _null_;
  pos = kindex('BONJOUR MONDE', 'MONDE');
  put 'KINDEX(BONJOUR MONDE, MONDE) = ' pos;
run;
