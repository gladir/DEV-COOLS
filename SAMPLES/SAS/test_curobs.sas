/* test_curobs.sas - CUROBS : numero d observation courante (stub) */
data _null_;
  dsid = 0;
  n = curobs(dsid);
  put 'CUROBS(0) = ' n;
run;
