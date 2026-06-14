/* test_kscan.sas - KSCAN : selectionner un mot dans une chaine DBCS (stub) */
data _null_;
  /* KSCAN(str, n, delims) */
  s = kscan('BONJOUR MONDE FIN', 2, ' ');
  put 'KSCAN(str,2,espace) = ' s;
run;
