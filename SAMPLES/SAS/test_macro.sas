/* test_macro.sas - Test du macro-langage SAS (TODO 21) */

/* --- %LET : definition de macro-variables --- */
%let nom = Alice;
%let age = 25;
%let ville = Montreal;

/* --- %PUT : affichage dans le log --- */
%put Nom = &nom;
%put Age = &age;
%put Ville = &ville;

/* --- Macro-variables automatiques --- */
%put Date systeme = &sysdate;
%put Heure systeme = &systime;
%put Version SAS = &sysver;

/* --- %LET avec expression --- */
%let x = 10;
%let y = 20;
%put x = &x;
%put y = &y;

/* --- %MACRO / %MEND : definition et appel --- */
%macro saluer(prenom, msg);
  %put Bonjour &prenom - &msg;
%mend saluer;

%saluer(Bob, bienvenue);

/* --- %MACRO sans parametres --- */
%macro header;
  %put === Debut du rapport ===;
%mend header;

%header;

/* --- %IF / %THEN / %ELSE --- */
%let score = 85;

%if &score >= 60 %then %put Resultat: REUSSI;

%let note = 45;
%if &note >= 60 %then %put Note: REUSSI;
%else %put Note: ECHOUE;

/* --- %DO / %END --- */
%let compteur = 3;
%do;
  %put Bloc DO execute;
%end;

/* --- %GLOBAL / %LOCAL --- */
%global g_var;
%let g_var = GLOBAL_VAL;
%put g_var = &g_var;

/* --- Fonctions macro --- */
/* %UPCASE */
%let minusc = bonjour;

/* %LENGTH - longueur d une chaine */
%let mot = Hello;

/* --- Utilisation dans un DATA step --- */
%let dsname = TRAVAIL;

data &dsname;
  x = &x;
  y = &y;
  total = x + y;
  put total;
run;

/* --- %IF avec %DO/%END --- */
%let mode = DEBUG;
%if &mode = DEBUG %then %do;
  %put Mode debug active;
  %put Trace ON;
%end;
%else %do;
  %put Mode production;
%end;

/* --- Fin du test --- */
%put === Fin des tests macro ===;
