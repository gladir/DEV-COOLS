/* test_index.sas - INDEX : position d une sous-chaine dans une chaine */
data _null_;
  /* INDEX(str, substr) */
  pos = index('BONJOUR MONDE', 'MONDE');
  put 'INDEX(BONJOUR MONDE, MONDE) = ' pos;
  pos2 = index('ABCABC', 'BC');
  put 'INDEX(ABCABC, BC) = ' pos2;
  pos3 = index('HELLO', 'XYZ');
  put 'INDEX(HELLO, XYZ) = ' pos3;
run;
