program test_debug;

function convert_to_jasmin_debug(s: String): String;
var
  result: String;
begin
  result := s;
  writeln('DEBUG: Testing string: "', s, '" (length=', Length(s), ')');
  writeln('DEBUG: Pos("ldd   ", s) = ', Pos('ldd   ', s));
  writeln('DEBUG: Pos("std   ", s) = ', Pos('std   ', s));
  
  if Pos('ldd   ', result) = 1 then begin
    result := 'iload ' + Copy(result, 7, Length(result));
    writeln('DEBUG: Converted to: "', result, '"');
  end
  else if Pos('std   ', result) = 1 then begin
    result := 'istore ' + Copy(result, 7, Length(result));
    writeln('DEBUG: Converted to: "', result, '"');
  end
  else begin
    writeln('DEBUG: No pattern matched');
  end;
  
  convert_to_jasmin_debug := result;
end;

begin
  writeln('Test 1:');
  writeln(convert_to_jasmin_debug('ldd   x'));
  writeln;
  writeln('Test 2:');
  writeln(convert_to_jasmin_debug('std   x'));
end.
