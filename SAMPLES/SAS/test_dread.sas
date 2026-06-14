/* test_dread.sas - DREAD : lire nom de membre de repertoire (stub) */
data _null_;
  did = 0;
  membre = dread(did, 1);
  put 'DREAD(0,1) = ' membre;
run;
