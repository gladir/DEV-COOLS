/* test_convxp.sas - CONVXP : convexite par periode (stub) */
data _null_;
  a = convxp(10, 5, 6, 1000, 1000);
  put 'CONVXP(10,5,6,1000,1000) = ' a;
run;
