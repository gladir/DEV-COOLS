/* test_arrays.sas - test TODO 15 : ARRAY, DIM, acces tableau, boucle DO */
data test;

  /* Declaration simple : 5 elements numeriques, noms automatiques */
  array scores {5};

  /* Initialiser tous les elements a zero */
  do i = 1 to dim(scores);
    scores{i} = 0;
  end;

  /* Affecter des valeurs */
  scores{1} = 10;
  scores{2} = 20;
  scores{3} = 30;
  scores{4} = 40;
  scores{5} = 50;

  /* Lire et afficher */
  do i = 1 to 5;
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

  /* Declaration avec plage numerotee : x1-x5 */
  array vals {5} x1-x5;
  do k = 1 to 5;
    vals{k} = k * 10;
  end;
  do k = 1 to dim(vals);
    put 'vals{' k '}=' vals{k};
  end;

  /* Tableau temporaire */
  array tmp {3} _temporary_;
  tmp{1} = 100;
  tmp{2} = 200;
  tmp{3} = 300;
  put 'tmp{2}=' tmp{2};

  /* Tableau multidimensionnel 2x3 */
  array mat {2,3};
  do r = 1 to 2;
    do c = 1 to 3;
      mat{c} = r * 10 + c;
    end;
  end;
  put 'mat{1}=' mat{1} ' mat{6}=' mat{6};

run;
