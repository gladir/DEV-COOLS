/* test_call_rxsubstr.sas - CALL RXSUBSTR : sous-chaine regex (stub) */
data _null_;
  rx = 0;
  src = 'Hello World';
  pos = 0;
  len = 0;
  call rxsubstr(rx, src, pos, len);
  put 'CALL RXSUBSTR : stub OK';
run;
