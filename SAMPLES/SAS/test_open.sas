/* test_open.sas - OPEN : ouvrir un dataset SAS */
data _null_;
  /* OPEN(dataset, mode) */
  dsid = open('SASHELP.CLASS', 'I');
  put 'OPEN(SASHELP.CLASS,I) = ' dsid '  (attendu: 1)';
  n = attrn(dsid, 'NOBS');
  put 'ATTRN(dsid,NOBS) = ' n '  (attendu: 1)';
  rc = close(dsid);
  put 'CLOSE(dsid) = ' rc '  (attendu: 0)';
  bad = open('', 'I');
  put 'OPEN(vide,I) = ' bad '  (attendu: 0)';
run;
