/* test_if_select.sas - test TODO 13 : IF/THEN/ELSE, SELECT/WHEN/OTHERWISE */
data test;
  x = 42;
  y = 10;

  /* IF simple */
  if x > 0 then put 'x est positif';

  /* IF/ELSE */
  if y > 20 then put 'y grand';
  else put 'y petit';

  /* IF avec bloc DO/END */
  if x = 42 then do;
    put 'x vaut 42';
    put 'reponse!';
  end;

  /* IF/ELSE IF/ELSE */
  if x < 0 then put 'negatif';
  else if x = 0 then put 'zero';
  else put 'positif';

  /* IF/ELSE avec bloc DO/END */
  if y > 100 then do;
    put 'y tres grand';
  end;
  else do;
    put 'y raisonnable';
  end;

  /* SELECT avec expression */
  z = 2;
  select (z);
    when (1) put 'un';
    when (2) put 'deux';
    when (3) put 'trois';
    otherwise put 'autre';
  end;

  /* SELECT sans expression (conditions booleennes) */
  select;
    when (x > 100) put 'x > 100';
    when (x > 50) put 'x > 50';
    when (x > 0) put 'x > 0';
    otherwise put 'x <= 0';
  end;

  /* SELECT avec valeurs multiples dans WHEN */
  w = 5;
  select (w);
    when (1, 2, 3) put 'petit';
    when (4, 5, 6) put 'moyen';
    otherwise put 'grand';
  end;

run;
