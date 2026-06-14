/* test_indexc.sas - INDEXC : position du premier caractere d un ensemble (stub) */
data _null_;
  /* INDEXC(str, chars) */
  pos = indexc('BONJOUR', 'AEIOU');
  put 'INDEXC(BONJOUR, voyelles) = ' pos;
  pos2 = indexc('HELLO', 'XYZ');
  put 'INDEXC(HELLO, XYZ) = ' pos2;
run;
