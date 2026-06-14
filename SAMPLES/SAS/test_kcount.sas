/* test_kcount.sas - KCOUNT : nombre de caracteres double-octet (stub) */
data _null_;
  n = kcount('BONJOUR');
  put 'KCOUNT(BONJOUR) = ' n;
  n2 = kcount('');
  put 'KCOUNT(vide) = ' n2;
run;
