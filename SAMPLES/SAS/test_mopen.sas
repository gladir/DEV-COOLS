/* test_mopen.sas - MOPEN : ouvrir un membre de repertoire (stub) */
data _null_;
  /* MOPEN(did, member, mode, reclen, cc) */
  fid = mopen(0, 'TEST', 'I', 80, ' ');
  put 'MOPEN(0,TEST,...) = ' fid;
run;
