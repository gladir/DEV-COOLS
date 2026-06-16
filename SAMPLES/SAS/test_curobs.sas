/* test_curobs.sas - CUROBS : numero d observation courante */
data _null_;
  dsid = 0;
  n = curobs(dsid);
  put 'CUROBS(0) = ' n '  (attendu: 1)';
  m = curobs(7);
  put 'CUROBS(7) = ' m '  (attendu: 7)';
run;
