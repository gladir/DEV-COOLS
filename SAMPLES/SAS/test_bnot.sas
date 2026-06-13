/* test_bnot.sas - BNOT : negation binaire */
data _null_;
  /* BNOT(0) = -1 (tous les bits a 1 en complement a 2) */
  a = bnot(0);
  put 'BNOT(0) = ' a;
  /* BNOT(-1) = 0 */
  b = bnot(-1);
  put 'BNOT(-1) = ' b;
  /* BNOT(255) = -256 */
  c = bnot(255);
  put 'BNOT(255) = ' c;
run;
