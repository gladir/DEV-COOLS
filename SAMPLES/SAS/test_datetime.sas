/* test_datetime.sas - DATETIME : date et heure courante SAS (stub) */
data _null_;
  dt = datetime();
  put 'DATETIME() = ' dt;
run;
