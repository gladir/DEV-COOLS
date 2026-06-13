/* test_attrn.sas - ATTRN : attribut numerique d un dataset (stub) */
data test1;
  x = 10;
run;

data _null_;
  dsid = 1;
  n = attrn(dsid, 'NOBS');
  put 'ATTRN = ' n;
run;
