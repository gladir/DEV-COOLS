/* test_ksubstr.sas - KSUBSTR : extraire une sous-chaine DBCS (stub) */
data _null_;
  /* KSUBSTR(str, pos, len) */
  s = ksubstr('BONJOUR', 4, 4);
  put 'KSUBSTR(BONJOUR,4,4) = ' s;
run;
