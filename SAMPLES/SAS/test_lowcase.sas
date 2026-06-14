/* test_lowcase.sas - LOWCASE : convertir en minuscules */
data _null_;
  s = lowcase('BONJOUR MONDE');
  put 'LOWCASE(BONJOUR MONDE) = ' s;
  s2 = lowcase('SAS');
  put 'LOWCASE(SAS) = ' s2;
run;
