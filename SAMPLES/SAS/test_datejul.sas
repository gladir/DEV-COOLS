/* test_datejul.sas - DATEJUL : date julienne vers SAS (stub) */
data _null_;
  /* DATEJUL(yyddd) -- 2023365 = 31 dec 2023 (stub=0) */
  a = datejul(2023365);
  put 'DATEJUL(2023365) = ' a;
  b = datejul(2024001);
  put 'DATEJUL(2024001) = ' b;
run;
