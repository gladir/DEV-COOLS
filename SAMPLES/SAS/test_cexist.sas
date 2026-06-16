/* test_cexist.sas - CEXIST : existence de catalogue/chemin */
data _null_;
  present = cexist('SAMPLES\SAS\test_cexist.sas', '');
  absent = cexist('SAMPLES\SAS\__absent__.cat', '');
  put 'CEXIST present=' present '  (attendu: 1)';
  put 'CEXIST absent=' absent '  (attendu: 0)';
run;
