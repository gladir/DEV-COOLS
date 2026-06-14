/* test_ksubstrb.sas - KSUBSTRB : extraire une sous-chaine en octets DBCS (stub) */
data _null_;
  /* KSUBSTRB(str, pos, len) */
  s = ksubstrb('BONJOUR', 1, 3);
  put 'KSUBSTRB(BONJOUR,1,3) = ' s;
run;
