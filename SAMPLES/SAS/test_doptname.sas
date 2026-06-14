/* test_doptname.sas - DOPTNAME : attribut d un repertoire (stub) */
data _null_;
  did = 0;
  nom = doptname(did, 1);
  put 'DOPTNAME(0,1) = ' nom;
run;
