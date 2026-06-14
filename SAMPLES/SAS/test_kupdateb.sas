/* test_kupdateb.sas - KUPDATEB : inserer/effacer/remplacer en octets (stub) */
data _null_;
  /* KUPDATEB(str, pos, del, ins) */
  s = kupdateb('BONJOUR', 1, 3, 'BON');
  put 'KUPDATEB(BONJOUR,1,3,BON) = ' s;
run;
