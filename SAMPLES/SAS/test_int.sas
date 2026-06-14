/* test_int.sas - INT : partie entiere d un nombre */
data _null_;
  a = int(3);
  put 'INT(3) = ' a;
  b = int(7);
  put 'INT(7) = ' b;
  c = int(0);
  put 'INT(0) = ' c;
run;
