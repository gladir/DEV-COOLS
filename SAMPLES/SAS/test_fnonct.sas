/* test_fnonct.sas - FNONCT : parametre non-centralise d une distribution F */
data _null_;
  /* FNONCT(f, ndf, ddf, prob), prob en pourcentage entier */
  a = fnonct(5, 2, 10, 95);
  put 'FNONCT(5,2,10,95) = ' a '  (attendu: 2)';
  b = fnonct(2, 2, 10, 95);
  put 'FNONCT(2,2,10,95) = ' b '  (attendu: 0)';
run;
