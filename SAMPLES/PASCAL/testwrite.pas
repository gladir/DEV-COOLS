program TestWrite;
var
  nombre: integer;
  lettre: char;
  flag: boolean;
  nom: string;

begin
  nombre := 42;
  lettre := 'A';
  flag := true;
  
  { Test Write et WriteLn avec différents types }
  WriteLn('Test du compilateur PC8086');
  Write('Nombre: ');
  WriteLn(nombre);
  
  Write('Lettre: ');
  WriteLn(lettre);
  
  Write('Booléen: ');
  WriteLn(flag);
  
  WriteLn('Fin du test');
end.
