unit Delphi.SQLite3.Backup.Test;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  Delphi.SQLite3,
  Delphi.SQLite3.Backup;

type

  [TestFixture]
  TSQLite3BackupTests = class
  private
    FTempDir: string;
    function MakePath(const AName: string): string;
    function CreatePopulatedDb(const APath: string; ARowCount: Integer): TSQLite3;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestBackupCreatesFile;

    [Test]
    procedure TestBackupContainsData;

    [Test]
    procedure TestBackupWithProgressReportsPages;

    [Test]
    procedure TestBackupProgressReachesZeroRemaining;

    [Test]
    procedure TestBackupPreservesAllRows;

    [Test]
    procedure TestRestoreFromFile;

    [Test]
    procedure TestRestoreWithProgress;

    [Test]
    procedure TestRestoreOverwritesExistingData;

    [Test]
    procedure TestGetAPIProcReturnsNilForBadName;
  end;

implementation

{ TSQLite3BackupTests }

procedure TSQLite3BackupTests.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'sqlite3_backup_test_' + FormatDateTime('hhnnsszzz', Now));
  ForceDirectories(FTempDir);
end;

procedure TSQLite3BackupTests.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TSQLite3BackupTests.MakePath(const AName: string): string;
begin
  Result := TPath.Combine(FTempDir, AName);
end;

function TSQLite3BackupTests.CreatePopulatedDb(const APath: string; ARowCount: Integer): TSQLite3;
var
  I: Integer;
begin
  Result := TSQLite3.Create(APath);
  Result.ExecSQL('CREATE TABLE data (id INTEGER PRIMARY KEY, payload TEXT)');
  Result.StartTransaction;
  for I := 1 to ARowCount do
    Result.ExecSQL('INSERT INTO data (payload) VALUES (:p)', ['Row ' + IntToStr(I)]);
  Result.Commit;
end;

procedure TSQLite3BackupTests.TestBackupCreatesFile;
var
  DB: TSQLite3;
  BackupPath: string;
begin
  DB := CreatePopulatedDb(MakePath('source.db'), 10);
  try
    BackupPath := MakePath('backup.db');
    Assert.IsFalse(TFile.Exists(BackupPath));
    TSQLite3Backup.BackupToFile(DB, BackupPath);
    Assert.IsTrue(TFile.Exists(BackupPath));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3BackupTests.TestBackupContainsData;
var
  DB, BackupDb: TSQLite3;
  BackupPath: string;
begin
  DB := CreatePopulatedDb(MakePath('source.db'), 5);
  try
    BackupPath := MakePath('backup.db');
    TSQLite3Backup.BackupToFile(DB, BackupPath);
  finally
    DB.Free;
  end;

  BackupDb := TSQLite3.Create(BackupPath, SQLITE_OPEN_READONLY);
  try
    Assert.AreEqual(5, BackupDb.QueryInt('SELECT COUNT(*) FROM data'));
    Assert.AreEqual('Row 1', BackupDb.QueryValue('SELECT payload FROM data WHERE id = 1'));
    Assert.AreEqual('Row 5', BackupDb.QueryValue('SELECT payload FROM data WHERE id = 5'));
  finally
    BackupDb.Free;
  end;
end;

procedure TSQLite3BackupTests.TestBackupWithProgressReportsPages;
var
  DB: TSQLite3;
  ProgressCalled: Boolean;
begin
  DB := CreatePopulatedDb(MakePath('source.db'), 100);
  try
    ProgressCalled := False;
    TSQLite3Backup.BackupToFile(DB, MakePath('backup.db'), 10,
      procedure(ARemaining, ATotal: Integer)
      begin
        ProgressCalled := True;
        Assert.IsTrue(ATotal > 0, 'Total page count should be positive');
        Assert.IsTrue(ARemaining >= 0, 'Remaining should be non-negative');
        Assert.IsTrue(ARemaining <= ATotal, 'Remaining should not exceed total');
      end);
    Assert.IsTrue(ProgressCalled, 'Progress callback should have been called');
  finally
    DB.Free;
  end;
end;

procedure TSQLite3BackupTests.TestBackupProgressReachesZeroRemaining;
var
  DB: TSQLite3;
  FinalRemaining: Integer;
begin
  DB := CreatePopulatedDb(MakePath('source.db'), 50);
  try
    FinalRemaining := -1;
    TSQLite3Backup.BackupToFile(DB, MakePath('backup.db'), 5,
      procedure(ARemaining, ATotal: Integer)
      begin
        FinalRemaining := ARemaining;
      end);
    Assert.AreEqual(0, FinalRemaining, 'Final progress callback should report 0 remaining');
  finally
    DB.Free;
  end;
end;

procedure TSQLite3BackupTests.TestBackupPreservesAllRows;
var
  DB, BackupDb: TSQLite3;
  BackupPath: string;
  RowCount: Integer;
begin
  RowCount := 500;
  DB := CreatePopulatedDb(MakePath('source.db'), RowCount);
  try
    BackupPath := MakePath('backup.db');
    TSQLite3Backup.BackupToFile(DB, BackupPath, 50, nil);
  finally
    DB.Free;
  end;

  BackupDb := TSQLite3.Create(BackupPath, SQLITE_OPEN_READONLY);
  try
    Assert.AreEqual(RowCount, BackupDb.QueryInt('SELECT COUNT(*) FROM data'));
  finally
    BackupDb.Free;
  end;
end;

procedure TSQLite3BackupTests.TestRestoreFromFile;
var
  SourceDb, TargetDb: TSQLite3;
  SourcePath, TargetPath: string;
begin
  SourcePath := MakePath('source.db');
  TargetPath := MakePath('target.db');

  SourceDb := CreatePopulatedDb(SourcePath, 20);
  SourceDb.Free;

  TargetDb := TSQLite3.Create(TargetPath);
  try
    TSQLite3Backup.RestoreFromFile(TargetDb, SourcePath);
    Assert.AreEqual(20, TargetDb.QueryInt('SELECT COUNT(*) FROM data'));
    Assert.AreEqual('Row 1', TargetDb.QueryValue('SELECT payload FROM data WHERE id = 1'));
  finally
    TargetDb.Free;
  end;
end;

procedure TSQLite3BackupTests.TestRestoreWithProgress;
var
  SourceDb, TargetDb: TSQLite3;
  SourcePath, TargetPath: string;
  ProgressCalled: Boolean;
begin
  SourcePath := MakePath('source.db');
  TargetPath := MakePath('target.db');

  SourceDb := CreatePopulatedDb(SourcePath, 100);
  SourceDb.Free;

  TargetDb := TSQLite3.Create(TargetPath);
  try
    ProgressCalled := False;
    TSQLite3Backup.RestoreFromFile(TargetDb, SourcePath, 10,
      procedure(ARemaining, ATotal: Integer)
      begin
        ProgressCalled := True;
      end);
    Assert.IsTrue(ProgressCalled, 'Progress callback should have been called');
    Assert.AreEqual(100, TargetDb.QueryInt('SELECT COUNT(*) FROM data'));
  finally
    TargetDb.Free;
  end;
end;

procedure TSQLite3BackupTests.TestRestoreOverwritesExistingData;
var
  SourceDb, TargetDb: TSQLite3;
  SourcePath, TargetPath: string;
begin
  SourcePath := MakePath('source.db');
  TargetPath := MakePath('target.db');

  SourceDb := CreatePopulatedDb(SourcePath, 10);
  SourceDb.Free;

  // Create target with different data.
  TargetDb := CreatePopulatedDb(TargetPath, 3);
  try
    Assert.AreEqual(3, TargetDb.QueryInt('SELECT COUNT(*) FROM data'));
    TSQLite3Backup.RestoreFromFile(TargetDb, SourcePath);
    Assert.AreEqual(10, TargetDb.QueryInt('SELECT COUNT(*) FROM data'));
  finally
    TargetDb.Free;
  end;
end;

procedure TSQLite3BackupTests.TestGetAPIProcReturnsNilForBadName;
begin
  Assert.IsNull(TSQLite3.GetAPIProc('sqlite3_nonexistent_function_xyz'));
end;

end.
