/* test_klength.sas - KLENGTH : longueur d un argument DBCS (stub) */
data _null_;
  n = klength('BONJOUR');
  put 'KLENGTH(BONJOUR) = ' n;
  n2 = klength('');
  put 'KLENGTH(vide) = ' n2;
run;
