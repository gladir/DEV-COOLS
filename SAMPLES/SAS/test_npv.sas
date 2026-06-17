/* test_npv.sas - NPV : valeur presente nette entiere */
data _null_;
  /* NPV(r, cf) */
  v = npv(5, 1000);
  put 'NPV(5,1000) = ' v '  (attendu: 952)';
  z = npv(-100, 1000);
  put 'NPV(-100,1000) = ' z '  (attendu: 0)';
run;
