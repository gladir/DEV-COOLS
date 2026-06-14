/* test_dinfo.sas - DINFO : informations sur un repertoire (stub) */
data _null_;
  did = 0;
  info = dinfo(did, 0);
  put 'DINFO(0,0) = ' info;
run;
