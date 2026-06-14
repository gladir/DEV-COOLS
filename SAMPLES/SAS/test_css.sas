/* test_css.sas - CSS : somme corrigee des carres (stub) */
data _null_;
  /* CSS de deux valeurs (stub=0) */
  a = css(3, 7);
  put 'CSS(3,7) = ' a;
  b = css(10, 20);
  put 'CSS(10,20) = ' b;
run;
