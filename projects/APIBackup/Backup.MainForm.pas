unit Backup.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Grids, Vcl.StdCtrls,
  Delphi.SQLite3, Delphi.SQLite3.Backup;

type
  TMain = class(TForm)
    StringGridDB: TStringGrid;
    butAdd: TButton;
    edtTodo: TEdit;
    butBackup: TButton;
    butRestore: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure butAddClick(Sender: TObject);
    procedure butBackupClick(Sender: TObject);
    procedure butRestoreClick(Sender: TObject);
  private
    FDb: TSQLite3;
    function DbPath: string;
    function BackupPath: string;
    procedure EnsureTable;
    procedure RefreshGrid;
  end;

var
  Main: TMain;

implementation

{$R *.dfm}

uses
  System.IOUtils;

function TMain.DbPath: string;
begin
  Result := TPath.Combine(ExtractFilePath(Application.ExeName), 'todo.db3');
end;

function TMain.BackupPath: string;
begin
  Result := TPath.Combine(ExtractFilePath(Application.ExeName), 'todo.backup.db3');
end;

procedure TMain.FormCreate(Sender: TObject);
begin
  FDb := TSQLite3.Create(DbPath);
  FDb.BusyTimeout(5000);
  FDb.SetPragma('journal_mode', 'WAL');
  FDb.SetPragma('foreign_keys', 'ON');
  EnsureTable;

  StringGridDB.ColCount := 2;
  StringGridDB.FixedCols := 1;
  StringGridDB.FixedRows := 1;
  StringGridDB.Cells[0, 0] := '#';
  StringGridDB.Cells[1, 0] := 'Todo';
  StringGridDB.ColWidths[0] := 40;
  StringGridDB.ColWidths[1] := StringGridDB.ClientWidth - 42;

  RefreshGrid;
end;

procedure TMain.FormDestroy(Sender: TObject);
begin
  FDb.Free;
end;

procedure TMain.EnsureTable;
begin
  FDb.ExecSQL('CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, entry TEXT NOT NULL)');
end;

procedure TMain.RefreshGrid;
var
  Q: TSQLite3Query;
  Row: Integer;
begin
  Q := FDb.Query('SELECT id, entry FROM todos ORDER BY id');
  try
    Row := 1;
    while Q.Next do
    begin
      if Row >= StringGridDB.RowCount then
        StringGridDB.RowCount := Row + 1;
      StringGridDB.Cells[0, Row] := IntToStr(Q.AsInteger(0));
      StringGridDB.Cells[1, Row] := Q.AsString(1);
      Inc(Row);
    end;
    // Clear any leftover rows from a previous larger result set.
    if Row > 1 then
    begin
      StringGridDB.RowCount := Row;
    end
    else
    begin
      StringGridDB.RowCount := 2;
      StringGridDB.Cells[0, 1] := '';
      StringGridDB.Cells[1, 1] := '';
    end;
  finally
    Q.Free;
  end;
end;

procedure TMain.butAddClick(Sender: TObject);
var
  Entry: string;
begin
  Entry := Trim(edtTodo.Text);
  if Entry = '' then
    Exit;
  FDb.ExecSQL('INSERT INTO todos (entry) VALUES (:e)', [Entry]);
  edtTodo.Clear;
  edtTodo.SetFocus;
  RefreshGrid;
end;

procedure TMain.butBackupClick(Sender: TObject);
begin
  TSQLite3Backup.BackupToFile(FDb, BackupPath);
  ShowMessage('Backup saved to ' + BackupPath);
end;

procedure TMain.butRestoreClick(Sender: TObject);
begin
  if not FileExists(BackupPath) then
  begin
    ShowMessage('No backup file found at ' + BackupPath);
    Exit;
  end;
  TSQLite3Backup.RestoreFromFile(FDb, BackupPath);
  RefreshGrid;
  ShowMessage('Restore complete.');
end;

end.
