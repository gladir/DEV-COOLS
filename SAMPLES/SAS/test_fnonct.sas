/* test_fnonct.sas - FNONCT : parametre non-centralisé d une distribution F (stub) */
data _null_;
  /* FNONCT(f, ndf, ddf, prob) */
  a = fnonct(4.0, 2, 10, 0.05);
  put 'FNONCT(4,2,10,0.05) = ' a;
run;
