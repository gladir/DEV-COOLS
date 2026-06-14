/* test_getoption.sas - GETOPTION : valeur d une option SAS (stub) */
data _null_;
  opt = getoption('LINESIZE');
  put 'GETOPTION(LINESIZE) = ' opt;
  opt2 = getoption('NODATE');
  put 'GETOPTION(NODATE) = ' opt2;
run;
