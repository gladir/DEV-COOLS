/* test_fappend.sas - FAPPEND : ajouter une ligne a un fichier (stub) */
data _null_;
  fid = 0;
  rc = fappend(fid);
  put 'FAPPEND(0) = ' rc;
run;
