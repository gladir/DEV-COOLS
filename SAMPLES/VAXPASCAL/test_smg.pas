{ test_smg.pas - Appels SMG$, stubs VMS }
program test_smg;
var
  display_id  : integer;
  pasteboard  : integer;
  keyboard_id : integer;
  status      : integer;
begin
  { Les appels SMG$ sont des stubs sous DOS }
  { Ils retournent SS$_NORMAL (1) }
  status := smg$create_pasteboard(pasteboard);
  writeln('smg$create_pasteboard status = ', status);

  status := smg$create_virtual_display(24, 80, display_id);
  writeln('smg$create_virtual_display status = ', status);

  status := smg$create_virtual_keyboard(keyboard_id);
  writeln('smg$create_virtual_keyboard status = ', status);

  status := smg$paste_virtual_display(display_id, pasteboard, 1, 1);
  writeln('smg$paste_virtual_display status = ', status);

  status := smg$put_chars(display_id, 'Hello SMG!', 1, 1);
  writeln('smg$put_chars status = ', status);

  status := smg$delete_virtual_display(display_id);
  writeln('smg$delete_virtual_display status = ', status);

  status := smg$delete_pasteboard(pasteboard);
  writeln('smg$delete_pasteboard status = ', status);

  writeln('Test SMG stubs termine.');
end.
