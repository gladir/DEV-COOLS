/* test_trim.sas - TRIM : supprime espaces finaux */
data _null_;
  s = trim('BONJOUR   ');
  put 'TRIM(BONJOUR   ) = [' s ']';
  s2 = trim('SAS');
  put 'TRIM(SAS) = [' s2 ']';
run;
