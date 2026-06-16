/* test_call_rxsubstr.sas - CALL RXSUBSTR : sous-chaine regex */
data _null_;
  rx = 0;
  src = 'Hello World';
  pos = 0;
  len = 0;
  call rxsubstr(rx, src, pos, len);
  put 'CALL RXSUBSTR pos=' pos ' len=' len '  (attendu: 1, 11)';
run;
