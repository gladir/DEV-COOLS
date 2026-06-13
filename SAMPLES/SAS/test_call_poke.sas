/* test_call_poke.sas - CALL POKE : ecrire en memoire */
data _null_;
  x = 100;
  a = addr(x);
  /* ecrit 999 a l adresse de x */
  call poke(a, 999);
  put 'CALL POKE x=' x;
run;
