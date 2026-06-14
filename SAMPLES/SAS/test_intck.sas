/* test_intck.sas - INTCK : nombre d intervalles entre deux dates (stub) */
data _null_;
  /* INTCK(interval, from, to) */
  n = intck('MONTH', 0, 365);
  put 'INTCK(MONTH,0,365) = ' n;
  d = intck('YEAR', 0, 730);
  put 'INTCK(YEAR,0,730) = ' d;
run;
