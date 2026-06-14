/* test_left.sas - LEFT : alignement a gauche d un argument */
data _null_;
  s = left('   BONJOUR');
  put 'LEFT(   BONJOUR) = ' s;
  s2 = left('  MONDE  ');
  put 'LEFT(  MONDE  ) = ' s2;
run;
