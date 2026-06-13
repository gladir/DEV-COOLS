/* test_blshift.sas - BLSHIFT : decalage binaire gauche */
data _null_;
  /* 1 SHL 4 = 16 */
  a = blshift(1, 4);
  put 'BLSHIFT(1,4) = ' a;
  /* 3 SHL 3 = 24 */
  b = blshift(3, 3);
  put 'BLSHIFT(3,3) = ' b;
  /* 1 SHL 0 = 1 */
  c = blshift(1, 0);
  put 'BLSHIFT(1,0) = ' c;
run;
