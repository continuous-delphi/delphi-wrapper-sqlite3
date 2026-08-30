(*

  delphi-wrapper-sqlite3
  https://github.com/continuous-delphi/delphi-wrapper-sqlite3

  Multi-platform SQLite3 class library for Delphi

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.SQLite3;

interface

uses
  System.SysUtils;

const
  // Open flags for TSQLite3.Create. Combine with OR.
  SQLITE_OPEN_READONLY      = $00000001;
  SQLITE_OPEN_READWRITE     = $00000002;
  SQLITE_OPEN_CREATE        = $00000004;
  SQLITE_OPEN_URI           = $00000040;
  SQLITE_OPEN_MEMORY        = $00000080;
  SQLITE_OPEN_NOMUTEX       = $00008000;
  SQLITE_OPEN_FULLMUTEX     = $00010000;
  SQLITE_OPEN_SHAREDCACHE   = $00020000;
  SQLITE_OPEN_PRIVATECACHE  = $00040000;
  SQLITE_OPEN_NOFOLLOW      = $01000000;

type

  ESQLite3Error = class(Exception)
  private
    FErrorCode: Integer;
  public
    constructor Create(AErrorCode: Integer; const AMessage: string);
    property ErrorCode: Integer read FErrorCode;
  end;

  TSQLite3Query = class;

  // Wraps a TBytes value so it can be passed as a BLOB bind parameter through
  // an "array of const" list, e.g. ExecSQL(sql, [Blob(MyBytes)]). A dynamic
  // array cannot ride through "array of const" directly, so the value must be
  // wrapped. Create one with the Blob() factory function. An empty TBytes
  // binds a zero-length BLOB (distinct from NULL).
  ISQLite3Blob = interface
    ['{2E1B9D4A-6C3F-4B8E-9A7D-5F1C0E2D3A46}']
    function GetData: TBytes;
  end;

  // Return True to cancel the running operation.
  TSQLite3ProgressFunc = reference to function: Boolean;

  // TSQLite3 -- lightweight cross-platform Delphi wrapper for SQLite.
  //
  // Loads the platform-native SQLite library at runtime:
  //   Windows    winsqlite3.dll   (ships with Windows 10 1803+)
  //   Linux      libsqlite3.so    (install: apt install libsqlite3-0)
  //   macOS      libsqlite3.dylib (ships with macOS)
  //   iOS        libsqlite3.dylib (ships with iOS)
  //   Android    libsqlite.so     (ships with Android)
  //
  // Usage:
  //   var DB := TSQLite3.Create('mydata.db');
  //   try
  //     DB.ExecSQL('CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT)');
  //     DB.ExecSQL('INSERT INTO items (name) VALUES (:name)', ['Widget']);
  //     var Q := DB.Query('SELECT id, name FROM items WHERE id > :min', [0]);
  //     try
  //       while Q.Next do
  //         WriteLn(Q.AsInteger(0), ': ', Q.AsString(1));
  //     finally
  //       Q.Free;
  //     end;
  //   finally
  //     DB.Free;
  //   end;
  //
  // Calling convention:
  //   Windows Win32  stdcall  (winsqlite3.dll is a Windows system DLL)
  //   Windows Win64  stdcall  (single ABI on x64, annotation irrelevant)
  //   All POSIX      cdecl    (standard C convention)
  TSQLite3 = class
  private
    FHandle: Pointer;
    FProgressFunc: TSQLite3ProgressFunc;
    procedure Check(AResultCode: Integer);
    function PrepareStmt(const ASQL: string): Pointer;
    procedure BindParams(AStmt: Pointer; const AParams: array of const);
  public
    // Open (or create) a database. Default flags: read-write + create.
    constructor Create(const ADbPath: string; AFlags: Integer = SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE);
    destructor Destroy; override;

    // Execute DDL / DML with no result set.
    procedure ExecSQL(const ASQL: string); overload;
    procedure ExecSQL(const ASQL: string; const AParams: array of const); overload;

    // Execute a query and return a result set. Caller must free the result.
    function Query(const ASQL: string): TSQLite3Query; overload;
    function Query(const ASQL: string; const AParams: array of const): TSQLite3Query; overload;

    // Query helpers that return a single scalar value.
    // Raise ESQLite3Error if the query returns no rows.
    function QueryValue(const ASQL: string): string; overload;
    function QueryValue(const ASQL: string; const AParams: array of const): string; overload;
    function QueryInt(const ASQL: string): Integer; overload;
    function QueryInt(const ASQL: string; const AParams: array of const): Integer; overload;

    // Transactions.
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;

    // Set the busy timeout in milliseconds. When a table is locked, SQLite
    // will retry for up to AMilliseconds before returning SQLITE_BUSY.
    // Pass 0 to disable (fail immediately on lock).
    procedure BusyTimeout(AMilliseconds: Integer);

    // Get or set a PRAGMA value. SetPragma executes "PRAGMA name = value".
    // GetPragma executes "PRAGMA name" and returns the result as a string.
    procedure SetPragma(const AName, AValue: string);
    function GetPragma(const AName: string): string;

    // Register a progress callback invoked every AStepCount virtual machine
    // instructions. Return True from AFunc to cancel the running operation
    // (SQLite will return SQLITE_INTERRUPT). Call ClearProgressHandler to remove.
    procedure SetProgressHandler(AStepCount: Integer; AFunc: TSQLite3ProgressFunc);
    procedure ClearProgressHandler;

    // Number of rows changed by the most recent INSERT, UPDATE, or DELETE.
    function Changes: Integer;

    // Row ID of the most recent successful INSERT.
    function LastInsertRowId: Int64;

    // SQLite library version string (e.g. '3.39.4').
    class function LibVersion: string;

    // True if the platform SQLite library can be loaded on this system.
    class function IsAvailable: Boolean;

    // Resolve a raw SQLite API function by name from the loaded library.
    // Use this to access API functions not wrapped by TSQLite3 (e.g. backup,
    // user-defined functions). Returns nil if the export is not found.
    class function GetAPIProc(const AName: UTF8String): Pointer;

    property Handle: Pointer read FHandle;
  end;

  // -----------------------------------------------------------------------
  // TSQLite3Query -- result set (forward-only cursor)
  // -----------------------------------------------------------------------

  TSQLite3Query = class
  private
    FStmt: Pointer;
    FOwnerDb: TSQLite3;
    FHasRow: Boolean;
    FStepped: Boolean;
    FColCount: Integer;
  public
    // Do not call directly -- use TSQLite3.Query instead.
    constructor Create(AOwnerDb: TSQLite3; AStmt: Pointer);
    destructor Destroy; override;

    // Advance to the next row. Returns False when no more rows.
    function Next: Boolean;

    // True when the cursor is past the last row.
    function EOF: Boolean;

    // Column metadata.
    property ColumnCount: Integer read FColCount;
    function ColumnName(AIndex: Integer): string;

    // Column value accessors (0-based index).
    function AsString(AIndex: Integer): string;
    function AsInteger(AIndex: Integer): Integer;
    function AsInt64(AIndex: Integer): Int64;
    function AsFloat(AIndex: Integer): Double;
    function AsBlob(AIndex: Integer): TBytes;
    function IsNull(AIndex: Integer): Boolean;

    // Resolve a column name to its 0-based index. Returns -1 if not found.
    function IndexOf(const AName: string): Integer;
  end;

// Wrap a byte buffer as a BLOB bind parameter. Pass the result inside an
// "array of const" parameter list:
//   DB.ExecSQL('INSERT INTO t (data) VALUES (:d)', [Blob(MyBytes)]);
// An empty TBytes binds a zero-length BLOB (distinct from NULL).
function Blob(const AData: TBytes): ISQLite3Blob;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}
{$IFDEF POSIX}
uses
  Posix.Dlfcn;
{$ENDIF}

// =========================================================================
// SQLite constants
// =========================================================================

const
  SQLITE_OK    = 0;
  SQLITE_ERROR = 1;
  SQLITE_ROW   = 100;
  SQLITE_DONE  = 101;

  SQLITE_NULL  = 5;

  SQLITE_TRANSIENT: Pointer = Pointer(-1);

// =========================================================================
// Platform-specific library name and calling convention
// =========================================================================

{$IFDEF MSWINDOWS}
const
  SQLITE_LIB = 'winsqlite3.dll';
{$ENDIF}
{$IFDEF LINUX}
const
  // Runtime packages install libsqlite3.so.0 (the soname). The unversioned
  // libsqlite3.so symlink is only present when the -dev package is installed.
  // Try the soname first for maximum compatibility on server/container images.
  SQLITE_LIB          = 'libsqlite3.so.0';
  SQLITE_LIB_FALLBACK = 'libsqlite3.so';
{$ENDIF}
{$IFDEF MACOS}
  {$IFNDEF IOS}
const
  SQLITE_LIB = 'libsqlite3.dylib';
  {$ENDIF}
{$ENDIF}
{$IFDEF IOS}
const
  SQLITE_LIB = 'libsqlite3.dylib';
{$ENDIF}
{$IFDEF ANDROID}
const
  SQLITE_LIB = 'libsqlite.so';
{$ENDIF}

// Calling convention: stdcall on Windows, cdecl on POSIX.
// On Win64 there is a single calling convention so stdcall is harmless.
// Delphi.SQLite3.cc.inc expands to the correct convention for the target platform.

// =========================================================================
// Platform-agnostic module handle type
// =========================================================================

type
  TModuleHandle = {$IFDEF MSWINDOWS}HMODULE{$ELSE}NativeUInt{$ENDIF};

// =========================================================================
// Function pointer types
// =========================================================================

type
  TSQLitePtr = Pointer;  // sqlite3 *
  TStmtPtr   = Pointer;  // sqlite3_stmt *

var
  _sqlite3_open_v2:           function(const filename: PUTF8Char; var db: TSQLitePtr; flags: Integer; const zVfs: PUTF8Char): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_close:             function(db: TSQLitePtr): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_busy_timeout:      function(db: TSQLitePtr; ms: Integer): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_errmsg:            function(db: TSQLitePtr): PUTF8Char; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_exec:              function(db: TSQLitePtr; const sql: PUTF8Char; callback, cbArg: Pointer; errmsg: PPAnsiChar): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_free:              procedure(p: Pointer); {$I Delphi.SQLite3.cc.inc};
  _sqlite3_prepare_v2:        function(db: TSQLitePtr; const sql: PUTF8Char; nByte: Integer; var stmt: TStmtPtr; tail: PPAnsiChar): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_step:              function(stmt: TStmtPtr): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_reset:             function(stmt: TStmtPtr): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_finalize:          function(stmt: TStmtPtr): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_bind_int:          function(stmt: TStmtPtr; idx, value: Integer): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_bind_int64:        function(stmt: TStmtPtr; idx: Integer; value: Int64): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_bind_double:       function(stmt: TStmtPtr; idx: Integer; value: Double): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_bind_text:         function(stmt: TStmtPtr; idx: Integer; const text: PUTF8Char; nByte: Integer; destructor_: Pointer): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_bind_blob:         function(stmt: TStmtPtr; idx: Integer; const data: Pointer; nByte: Integer; destructor_: Pointer): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_bind_null:         function(stmt: TStmtPtr; idx: Integer): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_count:      function(stmt: TStmtPtr): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_name:       function(stmt: TStmtPtr; col: Integer): PUTF8Char; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_type:       function(stmt: TStmtPtr; col: Integer): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_int:        function(stmt: TStmtPtr; col: Integer): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_int64:      function(stmt: TStmtPtr; col: Integer): Int64; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_double:     function(stmt: TStmtPtr; col: Integer): Double; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_text:       function(stmt: TStmtPtr; col: Integer): PUTF8Char; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_blob:       function(stmt: TStmtPtr; col: Integer): Pointer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_column_bytes:      function(stmt: TStmtPtr; col: Integer): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_changes:           function(db: TSQLitePtr): Integer; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_progress_handler:  procedure(db: TSQLitePtr; nOps: Integer; xProgress: Pointer; pArg: Pointer); {$I Delphi.SQLite3.cc.inc};
  _sqlite3_last_insert_rowid: function(db: TSQLitePtr): Int64; {$I Delphi.SQLite3.cc.inc};
  _sqlite3_libversion:        function: PUTF8Char; {$I Delphi.SQLite3.cc.inc};

  FModule: TModuleHandle = 0;
  FLoaded: Boolean = False;
  FLoadAttempted: Boolean = False;

// =========================================================================
// Platform-agnostic dynamic loading
// =========================================================================

function PlatformLoadLibrary(const AName: string): TModuleHandle;
begin
{$IFDEF MSWINDOWS}
  Result := LoadLibrary(PChar(AName));
{$ENDIF}
{$IFDEF POSIX}
  Result := dlopen(MarshaledAString(UTF8String(AName)), RTLD_LAZY);
{$ENDIF}
end;

function PlatformGetProc(AModule: TModuleHandle; const AName: UTF8String): Pointer;
begin
{$IFDEF MSWINDOWS}
  Result := GetProcAddress(AModule, PAnsiChar(AName));
{$ENDIF}
{$IFDEF POSIX}
  Result := dlsym(AModule, MarshaledAString(AName));
{$ENDIF}
end;

procedure PlatformFreeLibrary(AModule: TModuleHandle);
begin
{$IFDEF MSWINDOWS}
  FreeLibrary(AModule);
{$ENDIF}
{$IFDEF POSIX}
  dlclose(AModule);
{$ENDIF}
end;

// =========================================================================
// Loader
// =========================================================================

function TryLoadSQLite: Boolean;

  function Resolve(const AName: UTF8String): Pointer;
  begin
    Result := PlatformGetProc(FModule, AName);
    if Result = nil then
    begin
      PlatformFreeLibrary(FModule);
      FModule := 0;
      raise ESQLite3Error.Create(0, Format('%s: export "%s" not found', [SQLITE_LIB, string(AName)]));
    end;
  end;

begin
  if FLoaded then
    Exit(True);
  if FLoadAttempted then
    Exit(FLoaded);

  FLoadAttempted := True;
  FModule := PlatformLoadLibrary(SQLITE_LIB);
{$IFDEF LINUX}
  if FModule = 0 then
    FModule := PlatformLoadLibrary(SQLITE_LIB_FALLBACK);
{$ENDIF}
  if FModule = 0 then
    Exit(False);

  @_sqlite3_open_v2           := Resolve('sqlite3_open_v2');
  @_sqlite3_close             := Resolve('sqlite3_close');
  @_sqlite3_busy_timeout      := Resolve('sqlite3_busy_timeout');
  @_sqlite3_errmsg            := Resolve('sqlite3_errmsg');
  @_sqlite3_exec              := Resolve('sqlite3_exec');
  @_sqlite3_free              := Resolve('sqlite3_free');
  @_sqlite3_prepare_v2        := Resolve('sqlite3_prepare_v2');
  @_sqlite3_step              := Resolve('sqlite3_step');
  @_sqlite3_reset             := Resolve('sqlite3_reset');
  @_sqlite3_finalize          := Resolve('sqlite3_finalize');
  @_sqlite3_bind_int          := Resolve('sqlite3_bind_int');
  @_sqlite3_bind_int64        := Resolve('sqlite3_bind_int64');
  @_sqlite3_bind_double       := Resolve('sqlite3_bind_double');
  @_sqlite3_bind_text         := Resolve('sqlite3_bind_text');
  @_sqlite3_bind_blob         := Resolve('sqlite3_bind_blob');
  @_sqlite3_bind_null         := Resolve('sqlite3_bind_null');
  @_sqlite3_column_count      := Resolve('sqlite3_column_count');
  @_sqlite3_column_name       := Resolve('sqlite3_column_name');
  @_sqlite3_column_type       := Resolve('sqlite3_column_type');
  @_sqlite3_column_int        := Resolve('sqlite3_column_int');
  @_sqlite3_column_int64      := Resolve('sqlite3_column_int64');
  @_sqlite3_column_double     := Resolve('sqlite3_column_double');
  @_sqlite3_column_text       := Resolve('sqlite3_column_text');
  @_sqlite3_column_blob       := Resolve('sqlite3_column_blob');
  @_sqlite3_column_bytes      := Resolve('sqlite3_column_bytes');
  @_sqlite3_changes           := Resolve('sqlite3_changes');
  @_sqlite3_progress_handler  := Resolve('sqlite3_progress_handler');
  @_sqlite3_last_insert_rowid := Resolve('sqlite3_last_insert_rowid');
  @_sqlite3_libversion        := Resolve('sqlite3_libversion');

  FLoaded := True;
  Result := True;
end;

procedure EnsureLoaded;
begin
  if not TryLoadSQLite then
    raise ESQLite3Error.Create(0, 'Failed to load SQLite library (' + SQLITE_LIB + '). Ensure SQLite is installed on this platform.');
end;

// =========================================================================
// ESQLite3Error
// =========================================================================

constructor ESQLite3Error.Create(AErrorCode: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
end;

// =========================================================================
// TSQLite3Blob -- BLOB bind-parameter wrapper (see Blob() factory)
// =========================================================================

type
  TSQLite3Blob = class(TInterfacedObject, ISQLite3Blob)
  private
    FData: TBytes;
    function GetData: TBytes;
  public
    constructor Create(const AData: TBytes);
  end;

constructor TSQLite3Blob.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
end;

function TSQLite3Blob.GetData: TBytes;
begin
  Result := FData;
end;

function Blob(const AData: TBytes): ISQLite3Blob;
begin
  Result := TSQLite3Blob.Create(AData);
end;

// =========================================================================
// TSQLite3
// =========================================================================

constructor TSQLite3.Create(const ADbPath: string; AFlags: Integer);
var
  Utf8Path: UTF8String;
begin
  inherited Create;
  EnsureLoaded;
  Utf8Path := UTF8String(ADbPath);
  Check(_sqlite3_open_v2(PUTF8Char(Utf8Path), FHandle, AFlags, nil));
end;

destructor TSQLite3.Destroy;
begin
  if FHandle <> nil then
    _sqlite3_close(FHandle);
  inherited;
end;

procedure TSQLite3.Check(AResultCode: Integer);
var
  Msg: string;
begin
  if AResultCode <> SQLITE_OK then
  begin
    if FHandle <> nil then
      Msg := string(UTF8String(_sqlite3_errmsg(FHandle)))
    else
      Msg := Format('SQLite error %d', [AResultCode]);
    raise ESQLite3Error.Create(AResultCode, Msg);
  end;
end;

function TSQLite3.PrepareStmt(const ASQL: string): Pointer;
var
  Utf8SQL: UTF8String;
begin
  Utf8SQL := UTF8String(ASQL);
  Result := nil;
  Check(_sqlite3_prepare_v2(FHandle, PUTF8Char(Utf8SQL), -1, Result, nil));
  if Result = nil then
    raise ESQLite3Error.Create(SQLITE_ERROR, 'Failed to prepare statement');
end;

procedure TSQLite3.BindParams(AStmt: Pointer; const AParams: array of const);
var
  I, Idx: Integer;
  Utf8: UTF8String;
  S: string;
  BlobIntf: ISQLite3Blob;
  Bytes: TBytes;
begin
  for I := 0 to High(AParams) do
  begin
    Idx := I + 1;  // SQLite parameters are 1-based.
    case AParams[I].VType of
      vtInteger:
        Check(_sqlite3_bind_int(AStmt, Idx, AParams[I].VInteger));
      vtBoolean:
        Check(_sqlite3_bind_int(AStmt, Idx, Ord(AParams[I].VBoolean)));
      vtInt64:
        Check(_sqlite3_bind_int64(AStmt, Idx, AParams[I].VInt64^));
      vtExtended:
        Check(_sqlite3_bind_double(AStmt, Idx, AParams[I].VExtended^));
      vtCurrency:
        Check(_sqlite3_bind_double(AStmt, Idx, AParams[I].VCurrency^));
      vtUnicodeString:
        begin
          S := string(AParams[I].VUnicodeString);
          Utf8 := UTF8String(S);
          Check(_sqlite3_bind_text(AStmt, Idx, PUTF8Char(Utf8), Length(Utf8), SQLITE_TRANSIENT));
        end;
      vtAnsiString:
        begin
          Utf8 := UTF8String(AnsiString(AParams[I].VAnsiString));
          Check(_sqlite3_bind_text(AStmt, Idx, PUTF8Char(Utf8), Length(Utf8), SQLITE_TRANSIENT));
        end;
      vtWideString:
        begin
          S := string(WideString(AParams[I].VWideString));
          Utf8 := UTF8String(S);
          Check(_sqlite3_bind_text(AStmt, Idx, PUTF8Char(Utf8), Length(Utf8), SQLITE_TRANSIENT));
        end;
      vtChar:
        begin
          Utf8 := UTF8String(string(AParams[I].VChar));
          Check(_sqlite3_bind_text(AStmt, Idx, PUTF8Char(Utf8), Length(Utf8), SQLITE_TRANSIENT));
        end;
      vtWideChar:
        begin
          Utf8 := UTF8String(string(AParams[I].VWideChar));
          Check(_sqlite3_bind_text(AStmt, Idx, PUTF8Char(Utf8), Length(Utf8), SQLITE_TRANSIENT));
        end;
      vtPointer:
        begin
          if AParams[I].VPointer = nil then
            Check(_sqlite3_bind_null(AStmt, Idx))
          else
            raise ESQLite3Error.Create(0, Format('Unsupported non-nil pointer parameter at index %d', [I]));
        end;
      vtInterface:
        begin
          if Supports(IInterface(AParams[I].VInterface), ISQLite3Blob, BlobIntf) then
          begin
            Bytes := BlobIntf.GetData;
            // Pass a non-nil pointer even for an empty buffer: sqlite3_bind_blob
            // with a NULL data pointer binds NULL, but we want a zero-length BLOB.
            // @Bytes is always a valid stack address; SQLITE_TRANSIENT copies nByte
            // (0) bytes, so its contents are never read for an empty buffer.
            if Length(Bytes) = 0 then
              Check(_sqlite3_bind_blob(AStmt, Idx, @Bytes, 0, SQLITE_TRANSIENT))
            else
              Check(_sqlite3_bind_blob(AStmt, Idx, @Bytes[0], Length(Bytes), SQLITE_TRANSIENT));
          end
          else
            raise ESQLite3Error.Create(0, Format('Unsupported interface parameter at index %d', [I]));
        end;
    else
      raise ESQLite3Error.Create(0, Format('Unsupported parameter type %d at index %d', [AParams[I].VType, I]));
    end;
  end;
end;

procedure TSQLite3.ExecSQL(const ASQL: string);
var
  Utf8SQL: UTF8String;
  ErrMsg: PAnsiChar;
  RC: Integer;
  Msg: string;
begin
  // sqlite3_exec runs every semicolon-separated statement in the string, so a
  // schema/migration script executes in full. (The parameterized overload uses
  // prepare/step and is single-statement -- positional params cannot be split
  // across statements.)
  Utf8SQL := UTF8String(ASQL);
  ErrMsg := nil;
  RC := _sqlite3_exec(FHandle, PUTF8Char(Utf8SQL), nil, nil, @ErrMsg);
  if RC <> SQLITE_OK then
  begin
    // On error sqlite3_exec allocates the message via sqlite3_malloc; copy it
    // to a Delphi string and free the C buffer to avoid a leak.
    if ErrMsg <> nil then
    begin
      Msg := string(UTF8String(ErrMsg));
      _sqlite3_free(ErrMsg);
    end
    else
      Msg := Format('SQLite error %d', [RC]);
    raise ESQLite3Error.Create(RC, Msg);
  end;
  // On success ErrMsg is left nil (nothing allocated); no free needed.
end;

procedure TSQLite3.ExecSQL(const ASQL: string; const AParams: array of const);
var
  Stmt: Pointer;
begin
  Stmt := PrepareStmt(ASQL);
  try
    BindParams(Stmt, AParams);
    case _sqlite3_step(Stmt) of
      SQLITE_DONE: ;
      SQLITE_ROW:  ;
    else
      Check(_sqlite3_reset(Stmt));
    end;
  finally
    _sqlite3_finalize(Stmt);
  end;
end;

function TSQLite3.Query(const ASQL: string): TSQLite3Query;
var
  Stmt: Pointer;
begin
  Stmt := PrepareStmt(ASQL);
  Result := TSQLite3Query.Create(Self, Stmt);
end;

function TSQLite3.Query(const ASQL: string; const AParams: array of const): TSQLite3Query;
var
  Stmt: Pointer;
begin
  Stmt := PrepareStmt(ASQL);
  try
    BindParams(Stmt, AParams);
  except
    _sqlite3_finalize(Stmt);
    raise;
  end;
  Result := TSQLite3Query.Create(Self, Stmt);
end;

function TSQLite3.QueryValue(const ASQL: string): string;
var
  Q: TSQLite3Query;
begin
  Q := Query(ASQL);
  try
    if not Q.Next then
      raise ESQLite3Error.Create(0, 'Query returned no rows');
    Result := Q.AsString(0);
  finally
    Q.Free;
  end;
end;

function TSQLite3.QueryValue(const ASQL: string; const AParams: array of const): string;
var
  Q: TSQLite3Query;
begin
  Q := Query(ASQL, AParams);
  try
    if not Q.Next then
      raise ESQLite3Error.Create(0, 'Query returned no rows');
    Result := Q.AsString(0);
  finally
    Q.Free;
  end;
end;

function TSQLite3.QueryInt(const ASQL: string): Integer;
var
  Q: TSQLite3Query;
begin
  Q := Query(ASQL);
  try
    if not Q.Next then
      raise ESQLite3Error.Create(0, 'Query returned no rows');
    Result := Q.AsInteger(0);
  finally
    Q.Free;
  end;
end;

function TSQLite3.QueryInt(const ASQL: string; const AParams: array of const): Integer;
var
  Q: TSQLite3Query;
begin
  Q := Query(ASQL, AParams);
  try
    if not Q.Next then
      raise ESQLite3Error.Create(0, 'Query returned no rows');
    Result := Q.AsInteger(0);
  finally
    Q.Free;
  end;
end;

procedure TSQLite3.StartTransaction;
begin
  ExecSQL('BEGIN TRANSACTION');
end;

procedure TSQLite3.Commit;
begin
  ExecSQL('COMMIT');
end;

procedure TSQLite3.Rollback;
begin
  ExecSQL('ROLLBACK');
end;

procedure TSQLite3.BusyTimeout(AMilliseconds: Integer);
begin
  Check(_sqlite3_busy_timeout(FHandle, AMilliseconds));
end;

procedure TSQLite3.SetPragma(const AName, AValue: string);
begin
  ExecSQL('PRAGMA ' + AName + ' = ' + AValue);
end;

function TSQLite3.GetPragma(const AName: string): string;
begin
  Result := QueryValue('PRAGMA ' + AName);
end;

// Trampoline: SQLite calls this with pArg = the TSQLite3 instance.
// Returns non-zero to cancel the operation.
function ProgressTrampoline(pArg: Pointer): Integer; {$I Delphi.SQLite3.cc.inc};
begin
  if Assigned(TSQLite3(pArg).FProgressFunc) and TSQLite3(pArg).FProgressFunc() then
    Result := 1
  else
    Result := 0;
end;

procedure TSQLite3.SetProgressHandler(AStepCount: Integer; AFunc: TSQLite3ProgressFunc);
begin
  FProgressFunc := AFunc;
  _sqlite3_progress_handler(FHandle, AStepCount, @ProgressTrampoline, Self);
end;

procedure TSQLite3.ClearProgressHandler;
begin
  _sqlite3_progress_handler(FHandle, 0, nil, nil);
  FProgressFunc := nil;
end;

function TSQLite3.Changes: Integer;
begin
  Result := _sqlite3_changes(FHandle);
end;

function TSQLite3.LastInsertRowId: Int64;
begin
  Result := _sqlite3_last_insert_rowid(FHandle);
end;

class function TSQLite3.LibVersion: string;
begin
  EnsureLoaded;
  Result := string(UTF8String(_sqlite3_libversion));
end;

class function TSQLite3.IsAvailable: Boolean;
begin
  Result := TryLoadSQLite;
end;

class function TSQLite3.GetAPIProc(const AName: UTF8String): Pointer;
begin
  EnsureLoaded;
  Result := PlatformGetProc(FModule, AName);
end;

// =========================================================================
// TSQLite3Query
// =========================================================================

constructor TSQLite3Query.Create(AOwnerDb: TSQLite3; AStmt: Pointer);
begin
  inherited Create;
  FOwnerDb := AOwnerDb;
  FStmt := AStmt;
  FHasRow := False;
  FStepped := False;
  FColCount := _sqlite3_column_count(FStmt);
end;

destructor TSQLite3Query.Destroy;
begin
  if FStmt <> nil then
    _sqlite3_finalize(FStmt);
  inherited;
end;

function TSQLite3Query.Next: Boolean;
var
  RC: Integer;
begin
  FStepped := True;
  RC := _sqlite3_step(FStmt);
  case RC of
    SQLITE_ROW:
      begin
        FHasRow := True;
        Result := True;
      end;
    SQLITE_DONE:
      begin
        FHasRow := False;
        Result := False;
      end;
  else
    FHasRow := False;
    FOwnerDb.Check(_sqlite3_reset(FStmt));
    Result := False;
  end;
end;

function TSQLite3Query.EOF: Boolean;
begin
  Result := FStepped and not FHasRow;
end;

function TSQLite3Query.ColumnName(AIndex: Integer): string;
begin
  Result := string(UTF8String(_sqlite3_column_name(FStmt, AIndex)));
end;

function TSQLite3Query.AsString(AIndex: Integer): string;
var
  P: PUTF8Char;
begin
  P := _sqlite3_column_text(FStmt, AIndex);
  if P = nil then
    Result := ''
  else
    Result := string(UTF8String(P));
end;

function TSQLite3Query.AsInteger(AIndex: Integer): Integer;
begin
  Result := _sqlite3_column_int(FStmt, AIndex);
end;

function TSQLite3Query.AsInt64(AIndex: Integer): Int64;
begin
  Result := _sqlite3_column_int64(FStmt, AIndex);
end;

function TSQLite3Query.AsFloat(AIndex: Integer): Double;
begin
  Result := _sqlite3_column_double(FStmt, AIndex);
end;

function TSQLite3Query.AsBlob(AIndex: Integer): TBytes;
var
  Size: Integer;
  Data: Pointer;
begin
  Size := _sqlite3_column_bytes(FStmt, AIndex);
  if Size = 0 then
    Exit(nil);
  Data := _sqlite3_column_blob(FStmt, AIndex);
  SetLength(Result, Size);
  Move(Data^, Result[0], Size);
end;

function TSQLite3Query.IsNull(AIndex: Integer): Boolean;
begin
  Result := _sqlite3_column_type(FStmt, AIndex) = SQLITE_NULL;
end;

function TSQLite3Query.IndexOf(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FColCount - 1 do
    if SameText(ColumnName(I), AName) then
      Exit(I);
  Result := -1;
end;

initialization

finalization
  if FModule <> 0 then
    PlatformFreeLibrary(FModule);

end.
