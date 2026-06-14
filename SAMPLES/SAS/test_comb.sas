/* test_comb.sas - COMB : combinaisons C(n,r) */
data _null_;
  /* C(5,2) = 10 */
  a = comb(5, 2);
  put 'COMB(5,2) = ' a;
  /* C(6,3) = 20 */
  b = comb(6, 3);
  put 'COMB(6,3) = ' b;
  /* C(10,0) = 1 */
  c = comb(10, 0);
  put 'COMB(10,0) = ' c;
  /* C(10,10) = 1 */
  d = comb(10, 10);
  put 'COMB(10,10) = ' d;
  /* C(4,2) = 6 */
  e = comb(4, 2);
  put 'COMB(4,2) = ' e;
run;
