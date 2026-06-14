/* test_kcompress.sas - KCOMPRESS : enlever des caracteres d une chaine (stub) */
data _null_;
  s = kcompress('BONJOUR', 'O');
  put 'KCOMPRESS(BONJOUR, O) = ' s;
run;
