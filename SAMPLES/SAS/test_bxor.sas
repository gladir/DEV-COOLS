/* test_bxor.sas - BXOR : OU exclusif binaire */
data _null_;
  /* 12 = 1100b, 10 = 1010b, 12 XOR 10 = 0110b = 6 */
  a = bxor(12, 10);
  put 'BXOR(12,10) = ' a;
  /* n XOR n = 0 */
  b = bxor(255, 255);
  put 'BXOR(255,255) = ' b;
  /* n XOR 0 = n */
  c = bxor(42, 0);
  put 'BXOR(42,0) = ' c;
run;
