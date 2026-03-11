/* merge.sas - SET, MERGE, BY, FIRST./LAST. */

/* SET avec un seul dataset */
data copie;
  set clients;
  put 'client copie';
run;

/* SET avec concatenation */
data combined;
  set ds_jan ds_feb;
run;

/* SET avec END= */
data check;
  set commandes end=eof;
  if eof then put 'Fin du dataset';
run;

/* MERGE avec BY */
data fusionne;
  merge clients commandes;
  by cust_id;
run;

/* BY avec FIRST. et LAST. */
data groupes;
  set ventes;
  by region;
  if first.region then total = 0;
  total + montant;
  if last.region then output;
run;

/* UPDATE maitre + transaction */
data maj;
  update master trans;
  by id;
run;

/* SET avec trois datasets */
data annee;
  set t1 t2 t3;
run;
