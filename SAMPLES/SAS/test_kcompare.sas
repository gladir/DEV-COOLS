/* test_kcompare.sas - KCOMPARE : comparaison de chaines DBCS (stub) */
data _null_;
  r = kcompare('BONJOUR', 'BONJOUR');
  put 'KCOMPARE(BONJOUR,BONJOUR) = ' r;
  r2 = kcompare('ABC', 'DEF');
  put 'KCOMPARE(ABC,DEF) = ' r2;
run;
