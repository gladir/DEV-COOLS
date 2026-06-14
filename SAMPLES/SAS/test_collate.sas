/* test_collate.sas - COLLATE : sequence de codes ASCII (stub) */
data _null_;
  s = collate(65, 70);
  put 'COLLATE(65,70) = ' s;
  t = collate(48, 57);
  put 'COLLATE(48,57) = ' t;
run;
