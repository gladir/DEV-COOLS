/* test_dsname.sas - DSNAME : nom du dataset associe (stub) */
data _null_;
  dsid = 0;
  nom = dsname(dsid);
  put 'DSNAME(0) = ' nom;
run;
