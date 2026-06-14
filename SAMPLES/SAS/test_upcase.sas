/* test_upcase.sas - UPCASE : convertit en majuscules */
data _null_;
  s = upcase('bonjour monde');
  put 'UPCASE(bonjour monde) = ' s;
  s2 = upcase('sas');
  put 'UPCASE(sas) = ' s2;
run;
