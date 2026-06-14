/* test_frlen.sas - FRLEN : taille du dernier enregistrement lu (stub) */
data _null_;
  fid = 0;
  n = frlen(fid);
  put 'FRLEN(0) = ' n;
run;
