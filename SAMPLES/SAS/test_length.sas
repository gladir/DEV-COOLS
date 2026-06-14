/* test_length.sas - LENGTH : longueur d un argument sans espaces finaux */
data _null_;
  n = length('BONJOUR');
  put 'LENGTH(BONJOUR) = ' n;
  n2 = length('HELLO   ');
  put 'LENGTH(HELLO   ) = ' n2;
  n3 = length('');
  put 'LENGTH(vide) = ' n3;
run;
