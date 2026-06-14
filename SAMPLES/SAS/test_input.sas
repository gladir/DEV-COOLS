/* test_input.sas - INPUT : convertir une chaine en valeur numerique (stub) */
data _null_;
  /* INPUT(source, informat) - informat passe comme chaine dans ce compilateur */
  n = input('123', 3);
  put 'INPUT(123, 3) = ' n;
  n2 = input('456', 5);
  put 'INPUT(456, 5) = ' n2;
run;
