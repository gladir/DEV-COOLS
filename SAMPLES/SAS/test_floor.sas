/* test_floor.sas - FLOOR : plus grand entier inferieur ou egal a x */
data _null_;
  a = floor(3.7);
  put 'FLOOR(3.7) = ' a;
  b = floor(-2.3);
  put 'FLOOR(-2.3) = ' b;
  c = floor(5);
  put 'FLOOR(5) = ' c;
run;
