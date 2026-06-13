/* test_call_system.sas - CALL SYSTEM : executer commande OS */
data _null_;
  put 'CALL SYSTEM : avant execution';
  call system('cmd /c echo CALL_SYSTEM_OK');
  put 'CALL SYSTEM : apres execution';
run;
