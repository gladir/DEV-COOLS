/* test_kverify.sas - KVERIFY : position du premier caractere unique (stub) */
data _null_;
  /* KVERIFY(str, chars) */
  pos = kverify('BONJOUR', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
  put 'KVERIFY(BONJOUR, alpha) = ' pos;
run;
