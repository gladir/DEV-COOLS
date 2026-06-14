/* test_daccdb.sas - DACCDB : depreciation balance degressif (stub) */
data _null_;
  /* DACCDB(cout, valresid, vie, periode, facteur) */
  a = daccdb(10000, 1000, 5, 3, 2);
  put 'DACCDB(10000,1000,5,3,2) = ' a;
run;
