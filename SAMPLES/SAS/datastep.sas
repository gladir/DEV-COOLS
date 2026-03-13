/* datastep.sas - DATA step, INPUT, DATALINES, observations */

/* DATA step simple avec affectations */
data employes;
  nom = 'Dupont';
  salaire = 3500;
  bonus = 500;
  total = salaire + bonus;
  put 'Employe:' nom ' total=' total;
  output;
run;

/* DATA step avec OUTPUT explicite */
data multi;
  x = 1;
  output;
  x = 2;
  output;
  x = 3;
  output;
run;

/* DATA step avec DELETE conditionnel */
data filtre;
  score = 55;
  if score < 60 then delete;
  put 'score=' score;
run;

/* DATA step avec STOP */
data limite;
  i = 0;
  do while (i < 100);
    i = i + 1;
    if i > 5 then stop;
    put 'i=' i;
  end;
run;

/* DATA step avec RETAIN */
data cumul;
  retain somme 0;
  val = 10;
  somme = somme + val;
  put 'somme=' somme;
run;
