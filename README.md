# delphi-wrapper-sqlite3

 # delphi-inspect

![delphi-wrapper-sqlite3 logo](https://continuous-delphi.github.io/assets/logos/delphi-wrapper-sqlite3-480x270.png)

[![Delphi](https://img.shields.io/badge/delphi-red)](https://www.embarcadero.com/products/delphi)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/continuous-delphi/delphi-wrapper-sqlite3)
[![Continuous Delphi](https://img.shields.io/badge/org-continuous--delphi-red)](https://github.com/continuous-delphi)


Lightweight cross-platform Delphi wrapper for SQLite. Dynamically loads the platform-native SQLite library at runtime. 

## Platform Support

| Platform | Library | Calling Convention | Availability |
|---|---|---|---|
| Windows Win32 | `winsqlite3.dll` | stdcall | Ships with Windows 10 1803+ |
| Windows Win64 | `winsqlite3.dll` | stdcall | Ships with Windows 10 1803+ |
| Linux x64 | `libsqlite3.so` | cdecl | `apt install libsqlite3-0` or equivalent |
| macOS x64/ARM | `libsqlite3.dylib` | cdecl | Ships with macOS |
| iOS ARM | `libsqlite3.dylib` | cdecl | Ships with iOS |
| Android ARM/x64 | `libsqlite.so` | cdecl | Ships with Android |

## Requirements

- Newer version of Delphi (uses inline variables, `PUTF8Char`)
- SQLite library available on the target platform (see table above)

## Quick Start

Add `Source\Delphi.SQLite3.pas` to your project (ensure `Source\` is in the include path for the `.inc` file).

```pascal
uses Delphi.SQLite3;

var DB := TSQLite3.Create('mydata.db');
try
  DB.ExecSQL('CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT, price REAL)');
  DB.ExecSQL('INSERT INTO items (name, price) VALUES (:n, :p)', ['Widget', 9.99]);

  var Q := DB.Query('SELECT id, name, price FROM items');
  try
    while Q.Next do
      WriteLn(Q.AsInteger(0), ' | ', Q.AsString(1), ' | ', Q.AsFloat(2):0:2);
  finally
    Q.Free;
  end;
finally
  DB.Free;
end;
```

## API Reference

### TSQLite3

Database connection. Opens (or creates) a SQLite database file.

```pascal
constructor Create(const ADbPath: string);
```

#### Execute

```pascal
// DDL or DML with no result set.
procedure ExecSQL(const ASQL: string);
procedure ExecSQL(const ASQL: string; const AParams: array of const);

// Query returning a result set. Caller must free the returned object.
function Query(const ASQL: string): TSQLite3Query;
function Query(const ASQL: string; const AParams: array of const): TSQLite3Query;
```

#### Scalar Helpers

Return the first column of the first row. Raise `ESQLite3Error` if the query returns no rows.

```pascal
function QueryValue(const ASQL: string): string;
function QueryValue(const ASQL: string; const AParams: array of const): string;
function QueryInt(const ASQL: string): Integer;
function QueryInt(const ASQL: string; const AParams: array of const): Integer;
```

#### Transactions

```pascal
procedure StartTransaction;
procedure Commit;
procedure Rollback;
```

#### Metadata

```pascal
function Changes: Integer;          // rows affected by last INSERT/UPDATE/DELETE
function LastInsertRowId: Int64;    // rowid of most recent INSERT
class function LibVersion: string;  // e.g. '3.39.4'
class function IsAvailable: Boolean;// True if the platform SQLite library can be loaded
```

### TSQLite3Query

Forward-only cursor returned by `TSQLite3.Query`. Call `Next` to advance; read columns by 0-based index.

```pascal
function Next: Boolean;             // advance to next row; False when done
function EOF: Boolean;              // True after the last row

property ColumnCount: Integer;
function ColumnName(AIndex: Integer): string;
function IndexOf(const AName: string): Integer;  // -1 if not found (case-insensitive)

function AsString(AIndex: Integer): string;
function AsInteger(AIndex: Integer): Integer;
function AsInt64(AIndex: Integer): Int64;
function AsFloat(AIndex: Integer): Double;
function AsBlob(AIndex: Integer): TBytes;
function IsNull(AIndex: Integer): Boolean;
```

### Parameter Binding

Parameters use `:name` placeholders in SQL and `array of const` values passed positionally. Supported Delphi types:

| Delphi type | SQLite binding |
|---|---|
| `Integer` | `sqlite3_bind_int` |
| `Int64` | `sqlite3_bind_int64` |
| `Double` / `Extended` | `sqlite3_bind_double` |
| `Currency` | `sqlite3_bind_double` |
| `string` | `sqlite3_bind_text` (UTF-8) |
| `Boolean` | `sqlite3_bind_int` (0 or 1) |
| `nil` | `sqlite3_bind_null` |

```pascal
DB.ExecSQL('INSERT INTO t (name, amount, active) VALUES (:n, :a, :f)', ['Bolt', 3.50, True]);
DB.ExecSQL('UPDATE t SET name = :n WHERE id = :id', ['Nut', 42]);
DB.ExecSQL('INSERT INTO t (optional) VALUES (:v)', [nil]);  // NULL
```

### Error Handling

All errors raise `ESQLite3Error` with the SQLite error code:

```pascal
type
  ESQLite3Error = class(Exception)
    property ErrorCode: Integer read FErrorCode;
  end;
```

```pascal
try
  DB.ExecSQL('SELECT * FROM nonexistent');
except
  on E: ESQLite3Error do
    WriteLn('SQLite error ', E.ErrorCode, ': ', E.Message);
end;
```

## Examples

### Transactions

```pascal
DB.StartTransaction;
try
  for var I := 1 to 1000 do
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['Item ' + I.ToString]);
  DB.Commit;
except
  DB.Rollback;
  raise;
end;
```

### Auto-increment IDs

```pascal
DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['New item']);
var NewId := DB.LastInsertRowId;
WriteLn('Inserted row ID: ', NewId);
```

### Column Lookup by Name

```pascal
var Q := DB.Query('SELECT id, name, price FROM items');
try
  var ColPrice := Q.IndexOf('price');
  while Q.Next do
    WriteLn(Q.AsFloat(ColPrice):0:2);
finally
  Q.Free;
end;
```

### Check Availability

```pascal
if TSQLite3.IsAvailable then
  WriteLn('SQLite ', TSQLite3.LibVersion)
else
  WriteLn('SQLite library not found on this platform');
```

## Technical Notes

### Calling Convention

The wrapper uses `stdcall` on Windows (matching `winsqlite3.dll`) and `cdecl` on all POSIX platforms. This is handled via the `Delphi.SQLite3.cc.inc` include file that expands to the correct convention for the target platform.

### String Encoding

All strings are converted to UTF-8 before passing to SQLite and converted back to Delphi `string` (UTF-16) on read. The conversions use `UTF8String` and `PUTF8Char` for type safety.

### Dynamic Loading

The library is loaded once on first use. On Windows this uses `LoadLibrary` / `GetProcAddress`; on POSIX platforms (Linux, macOS, iOS, Android) it uses `dlopen` / `dlsym` from `Posix.Dlfcn`. The module handle is freed in the unit `finalization` section.

If the library is not present, `TSQLite3.Create` raises `ESQLite3Error`. Use `TSQLite3.IsAvailable` to check without raising.

### Thread Safety

SQLite itself is thread-safe (serialized mode by default). However, a single `TSQLite3` instance and its associated `TSQLite3Query` objects should be used from one thread at a time, or the caller must serialize access. For multi-threaded applications, create a separate `TSQLite3` connection per thread.

## Demo Project

### APIBackup -- Todo List with Backup/Restore

A VCL application in `projects/APIBackup/` that demonstrates `TSQLite3` and `TSQLite3Backup` working together. The form has a `TStringGrid` showing todo entries from `todo.db3`, an edit control with an Add button to insert rows, and Backup/Restore buttons.

- **Create** -- opens (or creates) `todo.db3` on startup with WAL journal mode
- **Read** -- populates the grid from the `todos` table
- **Insert** -- adds a new row from the edit control
- **Backup** -- saves to `todo.backup.db3` via `TSQLite3Backup.BackupToFile` (single-file output, no WAL sidecars)
- **Restore** -- loads from the backup via `TSQLite3Backup.RestoreFromFile` and refreshes the grid

The backup unit (`Delphi.SQLite3.Backup.pas` in `source/`) also serves as a reference for extending `TSQLite3` via raw API access. It resolves `sqlite3_backup_init`/`step`/`finish`/`remaining`/`pagecount` at runtime using `TSQLite3.GetAPIProc` and `TSQLite3.Handle`, without modifying the core unit.

## Tests

The test suite uses DUnitX and covers 64 tests:

| Category | Tests |
|---|---|
| Availability and version | 2 |
| Open / close | 3 |
| DDL (CREATE TABLE) | 2 |
| INSERT / SELECT | 7 |
| Scalar query helpers | 5 |
| Result set navigation | 7 |
| UPDATE / DELETE | 3 |
| LastInsertRowId | 2 |
| Transactions | 2 |
| Open flags | 4 |
| Busy timeout | 2 |
| Pragmas | 6 |
| Progress handler | 3 |
| Error handling | 2 |
| Multiple queries | 1 |
| Type coercion | 2 |
| Blob read | 1 |
| NULL handling | 1 |
| Backup / restore | 9 |

### Running Tests

Open `Tests\Delphi.SQLite3.Tests.dpr` in the Delphi IDE and create a project file, or build from the command line:

```
dcc64 -Q -B -NSSystem;System.Win;Winapi ^
  -I"Source" ^
  -E"Tests\Win64\Debug" -N"Tests\Win64\Debug" ^
  -U"<RADStudio>\lib\Win64\release;<RADStudio>\lib\Win64\debug" ^
  Tests\Delphi.SQLite3.Tests.dpr
```

Run:

```
Tests\Win64\Debug\Delphi.SQLite3.Tests.exe --exit:Continue
```

### Project Layout

```
delphi-wrapper-sqlite3/
  source/
    Delphi.SQLite3.pas            -- core wrapper (TSQLite3, TSQLite3Query)
    Delphi.SQLite3.cc.inc         -- calling convention include (stdcall/cdecl)
    Delphi.SQLite3.Backup.pas     -- online backup/restore via raw API access
  tests/
    Delphi.SQLite3.Tests.dpr      -- DUnitX test project (64 tests)
    Delphi.SQLite3.Test.pas       -- core wrapper tests
    Delphi.SQLite3.Backup.Test.pas-- backup/restore tests
  projects/
    APIBackup/                    -- VCL demo: todo list with backup/restore
```

------------------------------------------------------------------------

![continuous-delphi logo](https://continuous-delphi.github.io/assets/logos/continuous-delphi-480x270.png)

## Part of Continuous Delphi

This tool is part of the [Continuous-Delphi](https://github.com/continuous-delphi)
ecosystem, focused on improving engineering discipline for long-lived Delphi systems.
