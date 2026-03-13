{ test_objects.pas - Objets et heritage pour TP2JS (TODO 17) }
program TestObjects;
type
  TAnimal = object
    Name: String;
    Age: Integer;
    constructor Init(AName: String; AAge: Integer);
    destructor Done; virtual;
    procedure Speak; virtual;
    function GetInfo: String;
  end;

  TDog = object(TAnimal)
    Breed: String;
    constructor Init(AName: String; AAge: Integer; ABreed: String);
    procedure Speak; virtual;
    function GetBreedInfo: String;
  end;

var
  A: TAnimal;
  D: TDog;

constructor TAnimal.Init(AName: String; AAge: Integer);
begin
  Name := AName;
  Age := AAge;
end;

destructor TAnimal.Done;
begin
  WriteLn('Destroying ', Name);
end;

procedure TAnimal.Speak;
begin
  WriteLn(Name, ' makes a sound');
end;

function TAnimal.GetInfo: String;
begin
  GetInfo := Name;
end;

constructor TDog.Init(AName: String; AAge: Integer; ABreed: String);
begin
  inherited Init(AName, AAge);
  Breed := ABreed;
end;

procedure TDog.Speak;
begin
  WriteLn(Name, ' says: Woof!');
end;

function TDog.GetBreedInfo: String;
begin
  GetBreedInfo := Breed;
end;

begin
  A.Init('Cat', 5);
  A.Speak;
  WriteLn('Animal: ', A.GetInfo);

  D.Init('Rex', 3, 'Labrador');
  D.Speak;
  WriteLn('Dog breed: ', D.GetBreedInfo);
  WriteLn('Test objects done');
end.
