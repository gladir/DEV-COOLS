/* test_filename.sas - FILENAME : associer un fileref a un chemin (stub) */
data _null_;
  rc = filename('MYFILE', 'C:\temp\test.txt', 'DISK');
  put 'FILENAME(MYFILE,...) = ' rc;
run;
