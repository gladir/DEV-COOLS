/* test_fpos.sas - FPOS : positionner le pointeur de colonne du FDB (stub) */
data _null_;
  fid = 0;
  rc = fpos(fid, 1);
  put 'FPOS(0,1) = ' rc;
run;
