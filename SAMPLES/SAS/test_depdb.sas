/* test_depdb.sas - DEPDB : depreciation balance degressif (stub) */
data _null_;
  /* DEPDB(cout, val_residuelle, vie, periode, facteur) */
  a = depdb(10000, 1000, 5, 1, 2);
  put 'DEPDB(10000,1000,5,1,2) = ' a;
  b = depdb(10000, 1000, 5, 2, 2);
  put 'DEPDB(10000,1000,5,2,2) = ' b;
run;
