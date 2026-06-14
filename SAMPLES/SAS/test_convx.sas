/* test_convx.sas - CONVX : convexite d une marge de liquidite (stub) */
data _null_;
  /* CONVX(n, yield, coupon, par, redemption) */
  a = convx(10, 5, 6, 1000, 1000);
  put 'CONVX(10,5,6,1000,1000) = ' a;
run;
