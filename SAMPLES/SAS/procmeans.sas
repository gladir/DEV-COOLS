/* procmeans.sas - PROC MEANS, N MEAN MIN MAX SUM */

data scores;
  note = 85;
  heures = 40;
  output;
  note = 92;
  heures = 35;
  output;
  note = 78;
  heures = 42;
  output;
run;

/* PROC MEANS simple */
proc means data=scores;
  var note heures;
run;

/* PROC MEANS avec stats specifiques */
proc means data=scores n min max sum;
  var note heures;
run;

/* PROC MEANS avec TITLE */
proc means data=scores;
  var note;
  title 'Statistiques des notes';
run;

/* PROC FREQ avec TABLES */
proc freq data=scores;
  tables note;
run;
