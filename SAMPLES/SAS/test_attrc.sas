/* test_attrc.sas - ATTRC : attribut caractere d un dataset (stub) */
data test1;
  x = 10;
run;

data _null_;
  dsid = 1;
  a = attrc(dsid, 'TYPE');
  put 'ATTRC = ' a;
run;
