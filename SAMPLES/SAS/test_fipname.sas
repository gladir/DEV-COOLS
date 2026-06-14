/* test_fipname.sas - FIPNAME : nom d etat US en majuscules depuis code FIPS (stub) */
data _null_;
  /* FIPNAME(code) retourne nom en majuscules */
  s = fipname(6);
  put 'FIPNAME(6) = ' s;
  t = fipname(48);
  put 'FIPNAME(48) = ' t;
run;
