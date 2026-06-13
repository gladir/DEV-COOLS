/* test_cexist.sas - CEXIST : existence de catalogue (stub) */
data _null_;
  /* CEXIST('WORK.FORMATS') -- stub retourne 0 */
  rep = cexist(0, 0);
  put 'CEXIST = ' rep;
run;
