/* test_indexw.sas - INDEXW : position du premier mot dans une chaine (stub) */
data _null_;
  /* INDEXW(str, word) */
  pos = indexw('BONJOUR MONDE', 'MONDE');
  put 'INDEXW(BONJOUR MONDE, MONDE) = ' pos;
  pos2 = indexw('HELLO WORLD', 'WORLD');
  put 'INDEXW(HELLO WORLD, WORLD) = ' pos2;
run;
