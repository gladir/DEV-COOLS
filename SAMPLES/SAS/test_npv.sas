/* test_npv.sas - NPV : valeur nette presente (pourcentage) (stub) */
data _null_;
  /* NPV(r, cf) */
  v = npv(5, 1000);
  put 'NPV(5,1000) = ' v;
run;
