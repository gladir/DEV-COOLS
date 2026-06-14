/* test_inputn.sas - INPUTN : convertir avec un format numerique (stub) */
data _null_;
  /* INPUTN(source, informat) */
  n = inputn('3.14', 'BEST12.');
  put 'INPUTN(3.14, BEST12.) = ' n;
run;
