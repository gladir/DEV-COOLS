/* test_fnote.sas - FNOTE : marquer la position courante dans un fichier (stub) */
data _null_;
  fid = 0;
  note = fnote(fid);
  put 'FNOTE(0) = ' note;
run;
