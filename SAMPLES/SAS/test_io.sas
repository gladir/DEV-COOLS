/* test_io.sas - test TODO 12 : PUT / INPUT / INFILE / FILE */
data test;
  x = 42;
  y = 10;
  put x y;
  put 'Hello SAS86!';
run;
