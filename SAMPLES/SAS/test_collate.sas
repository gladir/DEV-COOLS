/* test_collate.sas - COLLATE : sequence de codes ASCII */
data _null_;
  s = collate(65, 70);
  put 'COLLATE(65,70) = [' s ']  (attendu: ABCDEF)';
  t = collate(48, 57);
  put 'COLLATE(48,57) = [' t ']  (attendu: 0123456789)';
  z = collate(70, 65);
  put 'COLLATE(70,65) = [' z ']  (attendu: vide)';
run;
