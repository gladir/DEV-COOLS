/* test_inputc.sas - INPUTC : convertir avec un format caractere (stub) */
data _null_;
  /* INPUTC(source, informat) */
  s = inputc('BONJOUR', '$CHAR7.');
  put 'INPUTC(BONJOUR, $CHAR7.) = ' s;
run;
