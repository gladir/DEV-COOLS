/* test_kupcase.sas - KUPCASE : convertir en majuscules DBCS (stub) */
data _null_;
  s = kupcase('bonjour');
  put 'KUPCASE(bonjour) = ' s;
run;
