/* test_band.sas - BAND : ET binaire */
data _null_;
  /* 12 = 1100b, 10 = 1010b, 12 AND 10 = 1000b = 8 */
  a = band(12, 10);
  put 'BAND(12,10) = ' a;
  /* 255 AND 15 = 00001111b = 15 */
  b = band(255, 15);
  put 'BAND(255,15) = ' b;
  /* 0 AND n = 0 */
  c = band(0, 99);
  put 'BAND(0,99) = ' c;
run;
