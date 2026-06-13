/* test_call_rxfree.sas - CALL RXFREE : liberer regex (stub) */
data _null_;
  rx = 0;
  call rxfree(rx);
  put 'CALL RXFREE : stub OK';
run;
