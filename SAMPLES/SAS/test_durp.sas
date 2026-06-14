/* test_durp.sas - DURP : duree modifiee de portefeuille (stub) */
data _null_;
  /* DURP(n, yield, coupon, par, redemption) */
  a = durp(10, 5, 6, 1000, 1000);
  put 'DURP(10,5,6,1000,1000) = ' a;
run;
