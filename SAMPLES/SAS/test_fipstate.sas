/* test_fipstate.sas - FIPSTATE : code postal 2 lettres depuis code FIPS (stub) */
data _null_;
  /* FIPSTATE(code) retourne abreviation 2 lettres */
  s = fipstate(6);
  put 'FIPSTATE(6) = ' s;
  t = fipstate(48);
  put 'FIPSTATE(48) = ' t;
run;
