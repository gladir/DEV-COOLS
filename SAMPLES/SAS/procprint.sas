/* procprint.sas - PROC PRINT, VAR, WHERE, FORMAT */

data ventes;
  produit = 'Widget';
  prix = 25;
  quantite = 10;
  total = prix * quantite;
run;

/* PROC PRINT simple */
proc print data=ventes;
run;

/* PROC PRINT avec VAR */
proc print data=ventes;
  var produit total;
run;

/* PROC PRINT avec TITLE et FOOTNOTE */
proc print data=ventes;
  var produit prix quantite total;
  title 'Rapport de ventes';
  footnote 'Source: procprint.sas';
run;

/* PROC PRINT avec NOPRINT */
proc print data=ventes noprint;
  var prix;
run;

/* PROC SORT avec BY */
proc sort data=ventes out=ventes_tri;
  by prix;
run;
