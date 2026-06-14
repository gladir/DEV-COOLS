/* test_fipnamel.sas - FIPNAMEL : nom d etat US en casse mixte depuis code FIPS (stub) */
data _null_;
  /* FIPNAMEL(code) retourne nom en mixed case */
  s = fipnamel(6);
  put 'FIPNAMEL(6) = ' s;
  t = fipnamel(48);
  put 'FIPNAMEL(48) = ' t;
run;
