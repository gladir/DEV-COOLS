/* test_bor.sas - BOR : OU binaire */
data _null_;
  /* 12 = 1100b, 10 = 1010b, 12 OR 10 = 1110b = 14 */
  a = bor(12, 10);
  put 'BOR(12,10) = ' a;
  /* 0 OR n = n */
  b = bor(0, 42);
  put 'BOR(0,42) = ' b;
  /* 255 OR 0 = 255 */
  c = bor(255, 0);
  put 'BOR(255,0) = ' c;
run;
