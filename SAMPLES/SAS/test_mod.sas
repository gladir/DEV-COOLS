/* test_mod.sas - MOD : modulo (reste de la division) */
data _null_;
  a = mod(10, 3);
  put 'MOD(10,3) = ' a;
  b = mod(15, 4);
  put 'MOD(15,4) = ' b;
  c = mod(8, 4);
  put 'MOD(8,4) = ' c;
run;
