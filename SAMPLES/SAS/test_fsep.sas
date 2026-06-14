/* test_fsep.sas - FSEP : definir le delimiteur pour FGET (stub) */
data _null_;
  fid = 0;
  rc = fsep(fid, ',');
  put 'FSEP(0,comma) = ' rc;
run;
