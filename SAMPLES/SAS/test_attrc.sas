/* test_attrc.sas - ATTRC : attribut caractere d un dataset */
data test1;
  x = 10;
run;

data _null_;
  dsid = 1;
  a = attrc(dsid, 'TYPE');
  put 'ATTRC(TYPE) = ' a '  (attendu: DATA)';
  e = attrc(dsid, 'ENGINE');
  put 'ATTRC(ENGINE) = ' e '  (attendu: BASE)';
  bad = attrc(0, 'TYPE');
  put 'ATTRC(0,TYPE) = [' bad ']  (attendu: vide)';
run;
