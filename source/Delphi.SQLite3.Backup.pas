(*

  delphi-wrapper-sqlite3
  https://github.com/continuous-delphi/delphi-wrapper-sqlite3

  Multi-platform SQLite3 class library for Delphi

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.SQLite3.Backup;

interface

uses
  System.SysUtils,
  Delphi.SQLite3;

type

  TSQLite3BackupProgress = reference to procedure(ARemaining, APageCount: Integer);

  // TSQLite3Backup -- online backup using the raw SQLite backup API.
  //
  // Demonstrates how to use TSQLite3.Handle and TSQLite3.GetAPIProc to access
  // SQLite C API functions not wrapped by the main TSQLite3 class.
  //
  // The SQLite online backup API copies pages from a source database to a
  // destination database. Both databases remain usable during the copy.
  // The source can be written to while the backup is in progress -- SQLite
  // will restart the copy for any modified pages.
  //
  // Usage:
  //   var DB := TSQLite3.Create('production.db');
  //   try
  //     TSQLite3Backup.BackupToFile(DB, 'backup.db');
  //   finally
  //     DB.Free;
  //   end;
  //
  // With progress reporting:
  //   TSQLite3Backup.BackupToFile(DB, 'backup.db', 100,
  //     procedure(ARemaining, ATotal: Integer)
  //     begin
  //       WriteLn(Format('Progress: %d%%', [Round((ATotal - ARemaining) / ATotal * 100)]));
  //     end);
  //
  // See: https://www.sqlite.org/backup.html
  TSQLite3Backup = class
  private
    class var FResolved: Boolean;
    class var _backup_init:      function(pDest: Pointer; const zDestName: PUTF8Char; pSource: Pointer; const zSourceName: PUTF8Char): Pointer; {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    class var _backup_step:      function(p: Pointer; nPage: Integer): Integer; {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    class var _backup_finish:    function(p: Pointer): Integer; {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    class var _backup_remaining: function(p: Pointer): Integer; {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    class var _backup_pagecount: function(p: Pointer): Integer; {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    class procedure EnsureResolved;
  public
    // Back up ASource to a new file at ADestPath. Copies all pages in one step.
    class procedure BackupToFile(ASource: TSQLite3; const ADestPath: string); overload;

    // Back up ASource to ADestPath, copying APagesPerStep pages at a time.
    // AOnProgress is called after each step with the remaining and total page counts.
    class procedure BackupToFile(ASource: TSQLite3; const ADestPath: string; APagesPerStep: Integer; AOnProgress: TSQLite3BackupProgress); overload;

    // Restore a database file into ATarget, replacing its contents.
    class procedure RestoreFromFile(ATarget: TSQLite3; const ASourcePath: string); overload;

    // Restore with progress reporting.
    class procedure RestoreFromFile(ATarget: TSQLite3; const ASourcePath: string; APagesPerStep: Integer; AOnProgress: TSQLite3BackupProgress); overload;
  end;

implementation

const
  SQLITE_OK   = 0;
  SQLITE_DONE = 101;

class procedure TSQLite3Backup.EnsureResolved;

  procedure Require(AProc: Pointer; const AName: string);
  begin
    if AProc = nil then
      raise ESQLite3Error.Create(0, 'SQLite export not found: ' + AName);
  end;

begin
  if FResolved then
    Exit;
  @_backup_init      := TSQLite3.GetAPIProc('sqlite3_backup_init');
  @_backup_step      := TSQLite3.GetAPIProc('sqlite3_backup_step');
  @_backup_finish    := TSQLite3.GetAPIProc('sqlite3_backup_finish');
  @_backup_remaining := TSQLite3.GetAPIProc('sqlite3_backup_remaining');
  @_backup_pagecount := TSQLite3.GetAPIProc('sqlite3_backup_pagecount');
  Require(@_backup_init,      'sqlite3_backup_init');
  Require(@_backup_step,      'sqlite3_backup_step');
  Require(@_backup_finish,    'sqlite3_backup_finish');
  Require(@_backup_remaining, 'sqlite3_backup_remaining');
  Require(@_backup_pagecount, 'sqlite3_backup_pagecount');
  FResolved := True;
end;

class procedure TSQLite3Backup.BackupToFile(ASource: TSQLite3; const ADestPath: string);
begin
  BackupToFile(ASource, ADestPath, -1, nil);
end;

class procedure TSQLite3Backup.BackupToFile(ASource: TSQLite3; const ADestPath: string; APagesPerStep: Integer; AOnProgress: TSQLite3BackupProgress);
var
  Dest: TSQLite3;
  Backup: Pointer;
  RC: Integer;
begin
  EnsureResolved;
  Dest := TSQLite3.Create(ADestPath);
  try
    Backup := _backup_init(Dest.Handle, PUTF8Char(UTF8String('main')), ASource.Handle, PUTF8Char(UTF8String('main')));
    if Backup = nil then
      raise ESQLite3Error.Create(0, 'sqlite3_backup_init failed');
    try
      repeat
        RC := _backup_step(Backup, APagesPerStep);
        if Assigned(AOnProgress) then
          AOnProgress(_backup_remaining(Backup), _backup_pagecount(Backup));
      until (RC = SQLITE_DONE) or ((RC <> SQLITE_OK) and (RC <> 0));
      if (RC <> SQLITE_DONE) then
        raise ESQLite3Error.Create(RC, Format('sqlite3_backup_step failed with error %d', [RC]));
    finally
      _backup_finish(Backup);
    end;
    // Force a WAL checkpoint and switch to DELETE journal mode so the backup
    // is a single file (no leftover -wal and -shm files).
    Dest.SetPragma('journal_mode', 'DELETE');
  finally
    Dest.Free;
  end;
end;

class procedure TSQLite3Backup.RestoreFromFile(ATarget: TSQLite3; const ASourcePath: string);
begin
  RestoreFromFile(ATarget, ASourcePath, -1, nil);
end;

class procedure TSQLite3Backup.RestoreFromFile(ATarget: TSQLite3; const ASourcePath: string; APagesPerStep: Integer; AOnProgress: TSQLite3BackupProgress);
var
  Source: TSQLite3;
  Backup: Pointer;
  RC: Integer;
begin
  EnsureResolved;
  Source := TSQLite3.Create(ASourcePath, SQLITE_OPEN_READONLY);
  try
    Backup := _backup_init(ATarget.Handle, PUTF8Char(UTF8String('main')), Source.Handle, PUTF8Char(UTF8String('main')));
    if Backup = nil then
      raise ESQLite3Error.Create(0, 'sqlite3_backup_init failed');
    try
      repeat
        RC := _backup_step(Backup, APagesPerStep);
        if Assigned(AOnProgress) then
          AOnProgress(_backup_remaining(Backup), _backup_pagecount(Backup));
      until (RC = SQLITE_DONE) or ((RC <> SQLITE_OK) and (RC <> 0));
      if (RC <> SQLITE_DONE) then
        raise ESQLite3Error.Create(RC, Format('sqlite3_backup_step failed with error %d', [RC]));
    finally
      _backup_finish(Backup);
    end;
  finally
    Source.Free;
  end;
end;

end.
