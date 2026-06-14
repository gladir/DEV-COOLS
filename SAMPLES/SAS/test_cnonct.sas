/* test_cnonct.sas - CNONCT : parametre de non-centralite (stub) */
data _null_;
  /* CNONCT(chi2, df, prob) */
  a = cnonct(10, 5, 95);
  put 'CNONCT(10,5,95) = ' a;
run;
