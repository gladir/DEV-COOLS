/* test_kstrcat.sas - KSTRCAT : concatener des chaines DBCS (stub) */
data _null_;
  s = kstrcat('BON', 'JOUR');
  put 'KSTRCAT(BON,JOUR) = ' s;
run;
