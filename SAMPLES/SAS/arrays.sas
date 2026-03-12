/* arrays.sas - ARRAY, boucle DO sur tableaux, DIM */

data _null_;

  /* Declaration simple : 5 elements numeriques */
  array scores {5};

  /* Initialiser via boucle avec DIM */
  do i = 1 to dim(scores);
    scores{i} = i * 10;
  end;

  /* Afficher les valeurs */
  do i = 1 to dim(scores);
    put 'scores{' i '}=' scores{i};
  end;

  /* Somme via boucle */
  total = 0;
  do i = 1 to dim(scores);
    total = total + scores{i};
  end;
  put 'total=' total;

  /* Declaration avec noms explicites */
  array notes {3} math francais anglais;
  math = 15;
  francais = 12;
  anglais = 18;
  do j = 1 to dim(notes);
    put 'notes{' j '}=' notes{j};
  end;

  /* Tableau temporaire */
  array tmp {3} _temporary_;
  tmp{1} = 100;
  tmp{2} = 200;
  tmp{3} = 300;
  put 'tmp{2}=' tmp{2};

run;
