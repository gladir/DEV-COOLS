/* test_intnx.sas - INTNX : avancer une date par intervalle (stub) */
data _null_;
  /* INTNX(interval, from, n) */
  d = intnx('MONTH', 0, 3);
  put 'INTNX(MONTH,0,3) = ' d;
  d2 = intnx('YEAR', 0, 1);
  put 'INTNX(YEAR,0,1) = ' d2;
run;
