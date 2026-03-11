/* hello.sas - DATA _NULL_, PUT, chaines, variables */

data _null_;
  msg = 42;
  nom = 'SAS86';
  put 'Bonjour le monde!';
  put 'Compilateur:' nom;
  put 'La reponse est' msg;
run;

data _null_;
  a = 10;
  b = 25;
  somme = a + b;
  put 'a=' a ' b=' b ' somme=' somme;
run;
