/* test_compbl.sas - COMPBL : supprimer espaces multiples */
data _null_;
  s = 'Hello   World';
  r = compbl(s);
  put 'COMPBL("Hello   World") = ' r;
  t = 'Bonjour    tout    le    monde';
  u = compbl(t);
  put 'COMPBL(multi) = ' u;
  /* chaine sans espaces multiples : inchangee */
  v = 'Test OK';
  w = compbl(v);
  put 'COMPBL("Test OK") = ' w;
run;
