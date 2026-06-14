/* test_netpv.sas - NETPV : valeur nette presente (fraction) (stub) */
data _null_;
  /* NETPV(r, cf) */
  v = netpv(5, 1000);
  put 'NETPV(5,1000) = ' v;
run;
