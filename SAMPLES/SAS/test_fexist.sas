/* test_fexist.sas - FEXIST : existence d un fileref (stub) */
data _null_;
  rc = fexist('MYFILE');
  put 'FEXIST(MYFILE) = ' rc;
run;
