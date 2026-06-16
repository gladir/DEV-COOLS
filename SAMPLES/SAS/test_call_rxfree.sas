/* test_call_rxfree.sas - CALL RXFREE : liberer regex */
data _null_;
  rx = 123;
  call rxfree(rx);
  put 'CALL RXFREE rx=' rx '  (attendu: 0)';
run;
