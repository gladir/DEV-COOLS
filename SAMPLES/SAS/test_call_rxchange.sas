/* test_call_rxchange.sas - CALL RXCHANGE : substitution texte */
data _null_;
  rx = 0;
  src = 'Hello World';
  dst = ' ';
  call rxchange(rx, 1, src, 'World', 'SAS', dst);
  put 'CALL RXCHANGE dst=' dst '  (attendu: Hello SAS)';
run;
