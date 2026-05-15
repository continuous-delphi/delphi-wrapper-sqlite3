program Demo.Backup;

uses
  Vcl.Forms,
  Backup.MainForm in 'Backup.MainForm.pas' {Main},
  Delphi.SQLite3 in '..\..\Source\Delphi.SQLite3.pas',
  Delphi.SQLite3.Backup in '..\..\source\Delphi.SQLite3.Backup.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
