/* test_fwrite.sas - FWRITE : ecrire un enregistrement dans un fichier externe (stub) */
data _null_;
  fid = 0;
  rc = fwrite(fid);
  put 'FWRITE(0) = ' rc;
run;
