/* test_attrc.sas - ATTRC : attribut caractere d un dataset */
data test1;
  x = 10;
run;

data _null_;
  dsid = 1;
  a = attrc(dsid, 'TYPE');
  put 'ATTRC(TYPE) = ' a '  (attendu: DATA)';
run;
