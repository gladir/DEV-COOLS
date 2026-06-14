/* test_constant.sas - CONSTANT : constante mathematique (stub) */
data _null_;
  /* CONSTANT('E') = e = 2.71828... (stub=0) */
  e = constant(0);
  put 'CONSTANT(E) = ' e;
  /* CONSTANT('PI') = pi = 3.14159... (stub=0) */
  pi = constant(1);
  put 'CONSTANT(PI) = ' pi;
run;
