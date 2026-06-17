/* test_netpv.sas - NETPV : valeur presente nette entiere */
data _null_;
  /* NETPV(r, cf) */
  v = netpv(5, 1000);
  put 'NETPV(5,1000) = ' v '  (attendu: 952)';
  z = netpv(-100, 1000);
  put 'NETPV(-100,1000) = ' z '  (attendu: 0)';
run;
