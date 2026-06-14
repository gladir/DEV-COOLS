/* test_klowcase.sas - KLOWCASE : conversion en minuscules DBCS (stub) */
data _null_;
  s = klowcase('BONJOUR');
  put 'KLOWCASE(BONJOUR) = ' s;
run;
