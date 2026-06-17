/* test_filename.sas - FILENAME : associer un fileref a un chemin */
data _null_;
  rc = filename('MYFILE', 'C:\temp\test.txt', 'DISK');
  put 'FILENAME(MYFILE,...) = ' rc '  (attendu: 0)';
  bad = filename('', 'C:\temp\test.txt', 'DISK');
  put 'FILENAME(vide,...) = ' bad '  (attendu: 1)';
run;
