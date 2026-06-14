/* test_exist.sas - EXIST : existence d un dataset SAS (stub) */
data _null_;
  /* EXIST(dsname, type) */
  a = exist('SASHELP.CLASS', 'DATA');
  put 'EXIST(SASHELP.CLASS,DATA) = ' a;
  b = exist('WORK.NONEXIST', 'DATA');
  put 'EXIST(WORK.NONEXIST,DATA) = ' b;
run;
