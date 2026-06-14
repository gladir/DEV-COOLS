/* test_date.sas - DATE : date courante SAS (stub) */
data _null_;
  /* DATE() retourne la date courante (stub=0) */
  d = date();
  put 'DATE() = ' d;
  /* utilisation dans calcul */
  age = date() - 0;
  put 'DATE()-0 = ' age;
run;
