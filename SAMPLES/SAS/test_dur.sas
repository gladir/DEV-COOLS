/* test_dur.sas - DUR : duree modifiee d une marge de liquidite (stub) */
data _null_;
  /* DUR(n, yield, coupon, par, redemption) */
  a = dur(10, 5, 6, 1000, 1000);
  put 'DUR(10,5,6,1000,1000) = ' a;
run;
