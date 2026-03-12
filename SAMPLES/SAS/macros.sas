/* macros.sas - macro-variables, %MACRO/%MEND, %IF/%THEN */

/* %LET : definition de macro-variables */
%let nom = Alice;
%let age = 25;
%let ville = Montreal;

/* %PUT : affichage dans le log */
%put Nom = &nom;
%put Age = &age;
%put Ville = &ville;

/* Macro-variables automatiques */
%put Date systeme = &sysdate;
%put Version SAS = &sysver;

/* %MACRO / %MEND : definition et appel */
%macro saluer(prenom, msg);
  %put Bonjour &prenom - &msg;
%mend saluer;

%saluer(Bob, bienvenue);

/* %MACRO sans parametres */
%macro header;
  %put === Debut du rapport ===;
%mend header;

%header;

/* %IF / %THEN / %ELSE */
%let score = 85;
%if &score >= 60 %then %put Resultat: REUSSI;

%let note = 45;
%if &note >= 60 %then %put Note: REUSSI;
%else %put Note: ECHOUE;

/* %DO / %END */
%do;
  %put Bloc DO execute;
%end;

/* Utilisation dans un DATA step */
%let dsname = TRAVAIL;
data &dsname;
  x = 10;
  y = 20;
  total = x + y;
  put total;
run;

/* %IF avec %DO/%END */
%let mode = DEBUG;
%if &mode = DEBUG %then %do;
  %put Mode debug active;
%end;
%else %do;
  %put Mode production;
%end;

%put === Fin des tests macro ===;
