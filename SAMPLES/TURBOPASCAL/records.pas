{ records.pas - RECORD, WITH, variantes, affectation (TODO 25) }
program RecordsDemo;

type
  TPoint = record
    X, Y: Integer;
  end;

  TPerson = record
    Name: String;
    Age: Integer;
    Active: Boolean;
  end;

  TShape = record
    case Kind: Integer of
      1: (Radius: Integer);
      2: (Width, Height: Integer);
  end;

var
  P1, P2: TPoint;
  Person: TPerson;
  Shape: TShape;

begin
  { Initialisation de records }
  P1.X := 10;
  P1.Y := 20;
  WriteLn('P1 = (', P1.X, ', ', P1.Y, ')');

  { Affectation de record }
  P2 := P1;
  P2.X := 30;
  WriteLn('P2 = (', P2.X, ', ', P2.Y, ')');

  { WITH statement }
  with Person do
  begin
    Name := 'Alice';
    Age := 30;
    Active := True;
  end;
  WriteLn('Person: ', Person.Name, ', age ', Person.Age);

  { Record variante }
  Shape.Kind := 1;
  Shape.Radius := 5;
  WriteLn('Circle radius = ', Shape.Radius);

  Shape.Kind := 2;
  Shape.Width := 10;
  Shape.Height := 20;
  WriteLn('Rectangle = ', Shape.Width, ' x ', Shape.Height);

  WriteLn('Done.');
end.
