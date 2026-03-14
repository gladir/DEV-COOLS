/* test_loops.sas - test TODO 14 : DO / DO WHILE / DO UNTIL / LEAVE / CONTINUE / GOTO */
data test;

  /* DO simple (bloc sans boucle) */
  x = 10;
  do;
    x = x + 1;
    put 'bloc simple : x=' x;
  end;

  /* DO WHILE */
  i = 1;
  do while (i <= 5);
    put 'while : i=' i;
    i = i + 1;
  end;

  /* DO UNTIL (execute au moins une fois) */
  j = 1;
  do until (j > 5);
    put 'until : j=' j;
    j = j + 1;
  end;

  /* DO iteratif simple : DO var = start TO end */
  do k = 1 to 5;
    put 'iter : k=' k;
  end;

  /* DO iteratif avec BY */
  do m = 0 to 10 by 2;
    put 'by2 : m=' m;
  end;

  /* DO iteratif avec BY negatif */
  do n = 10 to 1 by -1;
    put 'rev : n=' n;
  end;

  /* LEAVE : sortir de la boucle */
  do p = 1 to 100;
    if p > 3 then leave;
    put 'leave : p=' p;
  end;

  /* CONTINUE : passer a l iteration suivante */
  do q = 1 to 5;
    if q = 3 then continue;
    put 'cont : q=' q;
  end;

  /* GOTO : saut inconditionnel */
  r = 0;
  goto skip;
  r = 999;
skip:
  put 'goto : r=' r;

  /* DO iteratif avec WHILE additionnel */
  s = 0;
  do t = 1 to 10 while (s < 15);
    s = s + t;
    put 'itwhile : t=' t ' s=' s;
  end;

  /* Boucles imbriquees */
  do a = 1 to 3;
    do b = 1 to 2;
      put 'imbr : a=' a ' b=' b;
    end;
  end;

run;
