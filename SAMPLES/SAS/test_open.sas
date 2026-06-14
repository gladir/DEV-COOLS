/* test_open.sas - OPEN : ouvrir un dataset SAS (stub) */
data _null_;
  /* OPEN(dataset, mode) */
  dsid = open('SASHELP.CLASS', 'I');
  put 'OPEN(SASHELP.CLASS,I) = ' dsid;
run;
