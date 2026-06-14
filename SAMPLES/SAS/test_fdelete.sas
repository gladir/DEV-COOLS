/* test_fdelete.sas - FDELETE : supprimer un fichier par fileref (stub) */
data _null_;
  rc = fdelete('MYFILE');
  put 'FDELETE(MYFILE) = ' rc;
run;
