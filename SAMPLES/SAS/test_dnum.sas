/* test_dnum.sas - DNUM : nombre de membres d un repertoire (stub) */
data _null_;
  did = 0;
  n = dnum(did);
  put 'DNUM(0) = ' n;
run;
