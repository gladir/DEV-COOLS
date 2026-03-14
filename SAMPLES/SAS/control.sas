/* control.sas - IF/THEN/ELSE, SELECT/WHEN, DO loops */

data _null_;
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
    put 'bonne reponse!';
  end;

  /* IF/ELSE IF/ELSE */
  if x < 0 then put 'negatif';
  else if x = 0 then put 'zero';
  else put 'positif';

  /* SELECT avec expression */
  z = 2;
  select (z);
    when (1) put 'un';
    when (2) put 'deux';
    when (3) put 'trois';
    otherwise put 'autre';
  end;

  /* SELECT sans expression */
  select;
    when (x > 100) put 'x > 100';
    when (x > 50) put 'x > 50';
    when (x > 0) put 'x > 0';
    otherwise put 'x <= 0';
  end;

  /* DO WHILE */
  i = 1;
  do while (i <= 5);
    put 'while i=' i;
    i = i + 1;
  end;

  /* DO UNTIL */
  j = 1;
  do until (j > 5);
    put 'until j=' j;
    j = j + 1;
  end;

  /* DO iteratif */
  do k = 1 to 3;
    put 'iter k=' k;
  end;

  /* DO avec BY */
  do m = 0 to 10 by 2;
    put 'by2 m=' m;
  end;
run;
