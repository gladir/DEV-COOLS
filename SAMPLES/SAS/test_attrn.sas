/* test_attrn.sas - ATTRN : attribut numerique d un dataset */
data test1;
  x = 10;
run;

data _null_;
  dsid = 1;
  n = attrn(dsid, 'NOBS');
  put 'ATTRN(NOBS) = ' n '  (attendu: 1)';
  v = attrn(dsid, 'NVARS');
  put 'ATTRN(NVARS) = ' v '  (attendu: 1)';
  bad = attrn(0, 'NOBS');
  put 'ATTRN(0,NOBS) = ' bad '  (attendu: 0)';
run;
