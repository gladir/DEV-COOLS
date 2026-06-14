/* test_fileref.sas - FILEREF : verifier l existence d un fileref (stub) */
data _null_;
  rc = fileref('MYFILE');
  put 'FILEREF(MYFILE) = ' rc;
run;
