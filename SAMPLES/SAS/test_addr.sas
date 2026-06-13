/* test_addr.sas - ADDR / ADDRLONG : adresse memoire d une variable */
data _null_;
  x = 42;
  a = addr(x);
  put 'ADDR(x) non nul = ' a;
  b = addrlong(x);
  put 'ADDRLONG(x) non nul = ' b;
run;
