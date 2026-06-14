/* test_foptname.sas - FOPTNAME : nom d un item d information de fichier (stub) */
data _null_;
  fid = 0;
  nom = foptname(fid, 1);
  put 'FOPTNAME(0,1) = ' nom;
run;
