/* test_compound.sas - COMPOUND : interet compose (stub) */
data _null_;
  /* COMPOUND(1000, 5, 10) : capital 1000, taux 5%, 10 periodes */
  a = compound(1000, 5, 10);
  put 'COMPOUND(1000,5,10) = ' a;
run;
