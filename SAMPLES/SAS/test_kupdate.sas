/* test_kupdate.sas - KUPDATE : inserer/effacer/remplacer des caracteres (stub) */
data _null_;
  /* KUPDATE(str, pos, del, ins) */
  s = kupdate('BONJOUR', 4, 4, 'SOIR');
  put 'KUPDATE(BONJOUR,4,4,SOIR) = ' s;
run;
