/* test_brshift.sas - BRSHIFT : decalage binaire droit */
data _null_;
  /* 64 SAR 3 = 8 */
  a = brshift(64, 3);
  put 'BRSHIFT(64,3) = ' a;
  /* 16 SAR 4 = 1 */
  b = brshift(16, 4);
  put 'BRSHIFT(16,4) = ' b;
  /* -8 SAR 1 = -4 (arithmetique, signe preserve) */
  c = brshift(-8, 1);
  put 'BRSHIFT(-8,1) = ' c;
run;
