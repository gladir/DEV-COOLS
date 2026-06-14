/* test_fclose.sas - FCLOSE : fermer un fichier externe (stub) */
data _null_;
  fid = 0;
  rc = fclose(fid);
  put 'FCLOSE(0) = ' rc;
run;
