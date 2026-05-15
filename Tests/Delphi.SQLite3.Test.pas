unit Delphi.SQLite3.Test;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  Delphi.SQLite3;

type

  [TestFixture]
  TSQLite3Tests = class
  private
    FTempDir: string;
    FDbPath: string;
    function NewDb: TSQLite3;
    function NewDbWithTable: TSQLite3;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -- Availability & version -------------------------------------------

    [Test]
    procedure TestIsAvailable;

    [Test]
    procedure TestLibVersion;

    // -- Open / close -----------------------------------------------------

    [Test]
    procedure TestCreateDatabase;

    [Test]
    procedure TestOpenExistingDatabase;

    [Test]
    procedure TestOpenCreatesFile;

    // -- DDL --------------------------------------------------------------

    [Test]
    procedure TestCreateTable;

    [Test]
    procedure TestCreateMultipleTables;

    // -- Insert / select --------------------------------------------------

    [Test]
    procedure TestInsertAndSelect;

    [Test]
    procedure TestInsertParameterized;

    [Test]
    procedure TestInsertMultipleRows;

    [Test]
    procedure TestInsertNullParameter;

    [Test]
    procedure TestInsertBooleanParameter;

    [Test]
    procedure TestInsertInt64Parameter;

    [Test]
    procedure TestInsertFloatParameter;

    // -- Query helpers ----------------------------------------------------

    [Test]
    procedure TestQueryValue;

    [Test]
    procedure TestQueryValueParameterized;

    [Test]
    procedure TestQueryInt;

    [Test]
    procedure TestQueryIntParameterized;

    [Test]
    procedure TestQueryValueNoRowsRaises;

    // -- Result set -------------------------------------------------------

    [Test]
    procedure TestQueryColumnCount;

    [Test]
    procedure TestQueryColumnNames;

    [Test]
    procedure TestQueryMultipleRows;

    [Test]
    procedure TestQueryEmptyResultSet;

    [Test]
    procedure TestQueryEOF;

    [Test]
    procedure TestQueryIsNull;

    [Test]
    procedure TestQueryIndexOf;

    [Test]
    procedure TestQueryIndexOfNotFound;

    [Test]
    procedure TestQueryAsBlob;

    // -- Update / delete --------------------------------------------------

    [Test]
    procedure TestUpdate;

    [Test]
    procedure TestDelete;

    [Test]
    procedure TestChangesCount;

    // -- LastInsertRowId --------------------------------------------------

    [Test]
    procedure TestLastInsertRowId;

    [Test]
    procedure TestLastInsertRowIdAutoIncrement;

    // -- Transactions -----------------------------------------------------

    [Test]
    procedure TestTransactionCommit;

    [Test]
    procedure TestTransactionRollback;

    // -- Error handling ---------------------------------------------------

    [Test]
    procedure TestBadSQLRaises;

    [Test]
    procedure TestErrorCodePopulated;

    // -- Multiple queries on same connection ------------------------------

    [Test]
    procedure TestMultipleSequentialQueries;

    // -- Type coercion ----------------------------------------------------

    [Test]
    procedure TestIntStoredAsTextReadback;

    [Test]
    procedure TestFloatPrecision;
  end;

implementation

{ TSQLite3Tests }

procedure TSQLite3Tests.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'delphi_sqlite3_test_' + FormatDateTime('hhnnsszzz', Now));
  ForceDirectories(FTempDir);
  FDbPath := TPath.Combine(FTempDir, 'test.db');
end;

procedure TSQLite3Tests.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TSQLite3Tests.NewDb: TSQLite3;
begin
  Result := TSQLite3.Create(FDbPath);
end;

function TSQLite3Tests.NewDbWithTable: TSQLite3;
begin
  Result := NewDb;
  Result.ExecSQL('CREATE TABLE items (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, value REAL, data BLOB)');
end;

// -- Availability & version -----------------------------------------------

procedure TSQLite3Tests.TestIsAvailable;
begin
  Assert.IsTrue(TSQLite3.IsAvailable, 'SQLite library should be available on this platform');
end;

procedure TSQLite3Tests.TestLibVersion;
var
  Ver: string;
begin
  Ver := TSQLite3.LibVersion;
  Assert.IsNotEmpty(Ver, 'Version should not be empty');
  Assert.IsTrue(Ver.StartsWith('3.'), 'Version should start with 3.');
end;

// -- Open / close ---------------------------------------------------------

procedure TSQLite3Tests.TestCreateDatabase;
var
  DB: TSQLite3;
begin
  DB := NewDb;
  try
    Assert.IsNotNull(DB.Handle);
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestOpenExistingDatabase;
var
  DB: TSQLite3;
begin
  DB := NewDb;
  try
    DB.ExecSQL('CREATE TABLE t (x INTEGER)');
  finally
    DB.Free;
  end;

  DB := NewDb;
  try
    Assert.AreEqual(1, DB.QueryInt('SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name = ''t'''));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestOpenCreatesFile;
var
  DB: TSQLite3;
begin
  Assert.IsFalse(TFile.Exists(FDbPath));
  DB := NewDb;
  try
    DB.ExecSQL('CREATE TABLE t (x INTEGER)');
  finally
    DB.Free;
  end;
  Assert.IsTrue(TFile.Exists(FDbPath));
end;

// -- DDL ------------------------------------------------------------------

procedure TSQLite3Tests.TestCreateTable;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    Assert.AreEqual(1, DB.QueryInt('SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name = ''items'''));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestCreateMultipleTables;
var
  DB: TSQLite3;
begin
  DB := NewDb;
  try
    DB.ExecSQL('CREATE TABLE a (id INTEGER PRIMARY KEY)');
    DB.ExecSQL('CREATE TABLE b (id INTEGER PRIMARY KEY)');
    Assert.AreEqual(2, DB.QueryInt('SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'''));
  finally
    DB.Free;
  end;
end;

// -- Insert / select ------------------------------------------------------

procedure TSQLite3Tests.TestInsertAndSelect;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name, value) VALUES (''Widget'', 9.99)');
    Assert.AreEqual('Widget', DB.QueryValue('SELECT name FROM items WHERE id = 1'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestInsertParameterized;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name, value) VALUES (:n, :v)', ['Gadget', 19.95]);
    Assert.AreEqual('Gadget', DB.QueryValue('SELECT name FROM items WHERE id = 1'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestInsertMultipleRows;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['Alpha']);
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['Beta']);
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['Gamma']);
    Assert.AreEqual(3, DB.QueryInt('SELECT COUNT(*) FROM items'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestInsertNullParameter;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name, value) VALUES (:n, :v)', ['Thing', nil]);
    Q := DB.Query('SELECT value FROM items WHERE id = 1');
    try
      Assert.IsTrue(Q.Next);
      Assert.IsTrue(Q.IsNull(0), 'value should be NULL');
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestInsertBooleanParameter;
var
  DB: TSQLite3;
begin
  DB := NewDb;
  try
    DB.ExecSQL('CREATE TABLE flags (name TEXT, active INTEGER)');
    DB.ExecSQL('INSERT INTO flags (name, active) VALUES (:n, :a)', ['feature', True]);
    Assert.AreEqual(1, DB.QueryInt('SELECT active FROM flags'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestInsertInt64Parameter;
var
  DB: TSQLite3;
  Big: Int64;
  Q: TSQLite3Query;
begin
  DB := NewDb;
  try
    DB.ExecSQL('CREATE TABLE big (val INTEGER)');
    Big := Int64(MaxInt) + 100;
    DB.ExecSQL('INSERT INTO big (val) VALUES (:v)', [Big]);
    Q := DB.Query('SELECT val FROM big');
    try
      Assert.IsTrue(Q.Next);
      Assert.AreEqual(Big, Q.AsInt64(0));
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestInsertFloatParameter;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name, value) VALUES (:n, :v)', ['Pi', 3.14159]);
    Q := DB.Query('SELECT value FROM items');
    try
      Assert.IsTrue(Q.Next);
      Assert.AreEqual(Double(3.14159), Q.AsFloat(0), 0.00001);
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

// -- Query helpers --------------------------------------------------------

procedure TSQLite3Tests.TestQueryValue;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''Bolt'')');
    Assert.AreEqual('Bolt', DB.QueryValue('SELECT name FROM items'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryValueParameterized;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['Nut']);
    Assert.AreEqual('Nut', DB.QueryValue('SELECT name FROM items WHERE name = :n', ['Nut']));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryInt;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''A'')');
    DB.ExecSQL('INSERT INTO items (name) VALUES (''B'')');
    Assert.AreEqual(2, DB.QueryInt('SELECT COUNT(*) FROM items'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryIntParameterized;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''X'')');
    Assert.AreEqual(1, DB.QueryInt('SELECT COUNT(*) FROM items WHERE name = :n', ['X']));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryValueNoRowsRaises;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    try
      DB.QueryValue('SELECT name FROM items');
      Assert.Fail('Should have raised ESQLite3Error');
    except
      on E: ESQLite3Error do
        ; // expected
    end;
  finally
    DB.Free;
  end;
end;

// -- Result set -----------------------------------------------------------

procedure TSQLite3Tests.TestQueryColumnCount;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name, value) VALUES (''X'', 1.0)');
    Q := DB.Query('SELECT id, name, value FROM items');
    try
      Assert.AreEqual(3, Q.ColumnCount);
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryColumnNames;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    Q := DB.Query('SELECT id, name, value FROM items');
    try
      Assert.AreEqual('id', Q.ColumnName(0));
      Assert.AreEqual('name', Q.ColumnName(1));
      Assert.AreEqual('value', Q.ColumnName(2));
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryMultipleRows;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
  Count: Integer;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['A']);
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['B']);
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['C']);

    Q := DB.Query('SELECT name FROM items ORDER BY name');
    try
      Count := 0;
      while Q.Next do
        Inc(Count);
      Assert.AreEqual(3, Count);
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryEmptyResultSet;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    Q := DB.Query('SELECT name FROM items');
    try
      Assert.IsFalse(Q.Next, 'Next should return False on empty result');
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryEOF;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''X'')');
    Q := DB.Query('SELECT name FROM items');
    try
      Assert.IsFalse(Q.EOF, 'EOF should be False before stepping');
      Q.Next;
      Assert.IsFalse(Q.EOF, 'EOF should be False on valid row');
      Q.Next;
      Assert.IsTrue(Q.EOF, 'EOF should be True after last row');
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryIsNull;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name, value) VALUES (''X'', NULL)');
    Q := DB.Query('SELECT value FROM items');
    try
      Assert.IsTrue(Q.Next);
      Assert.IsTrue(Q.IsNull(0));
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryIndexOf;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    Q := DB.Query('SELECT id, name, value FROM items');
    try
      Assert.AreEqual(0, Q.IndexOf('id'));
      Assert.AreEqual(1, Q.IndexOf('name'));
      Assert.AreEqual(2, Q.IndexOf('value'));
      Assert.AreEqual(1, Q.IndexOf('NAME'));  // case-insensitive
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryIndexOfNotFound;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    Q := DB.Query('SELECT id FROM items');
    try
      Assert.AreEqual(-1, Q.IndexOf('nonexistent'));
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestQueryAsBlob;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
  ReadBack: TBytes;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''BlobItem'')');
    DB.ExecSQL('UPDATE items SET data = X''DEADBEEF'' WHERE id = 1');

    Q := DB.Query('SELECT data FROM items WHERE id = 1');
    try
      Assert.IsTrue(Q.Next);
      ReadBack := Q.AsBlob(0);
      Assert.AreEqual(NativeInt(4), Length(ReadBack));
      Assert.AreEqual(Integer($DE), Integer(ReadBack[0]));
      Assert.AreEqual(Integer($AD), Integer(ReadBack[1]));
      Assert.AreEqual(Integer($BE), Integer(ReadBack[2]));
      Assert.AreEqual(Integer($EF), Integer(ReadBack[3]));
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

// -- Update / delete ------------------------------------------------------

procedure TSQLite3Tests.TestUpdate;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['Old']);
    DB.ExecSQL('UPDATE items SET name = :n WHERE id = :id', ['New', 1]);
    Assert.AreEqual('New', DB.QueryValue('SELECT name FROM items WHERE id = 1'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestDelete;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (:n)', ['Doomed']);
    Assert.AreEqual(1, DB.QueryInt('SELECT COUNT(*) FROM items'));
    DB.ExecSQL('DELETE FROM items WHERE id = :id', [1]);
    Assert.AreEqual(0, DB.QueryInt('SELECT COUNT(*) FROM items'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestChangesCount;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''A'')');
    DB.ExecSQL('INSERT INTO items (name) VALUES (''B'')');
    DB.ExecSQL('INSERT INTO items (name) VALUES (''C'')');
    DB.ExecSQL('DELETE FROM items WHERE name IN (''A'', ''B'')');
    Assert.AreEqual(2, DB.Changes);
  finally
    DB.Free;
  end;
end;

// -- LastInsertRowId ------------------------------------------------------

procedure TSQLite3Tests.TestLastInsertRowId;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''First'')');
    Assert.AreEqual(Int64(1), DB.LastInsertRowId);
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestLastInsertRowIdAutoIncrement;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''A'')');
    DB.ExecSQL('INSERT INTO items (name) VALUES (''B'')');
    DB.ExecSQL('INSERT INTO items (name) VALUES (''C'')');
    Assert.AreEqual(Int64(3), DB.LastInsertRowId);
  finally
    DB.Free;
  end;
end;

// -- Transactions ---------------------------------------------------------

procedure TSQLite3Tests.TestTransactionCommit;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.StartTransaction;
    DB.ExecSQL('INSERT INTO items (name) VALUES (''Committed'')');
    DB.Commit;
    Assert.AreEqual(1, DB.QueryInt('SELECT COUNT(*) FROM items'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestTransactionRollback;
var
  DB: TSQLite3;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''Keeper'')');
    DB.StartTransaction;
    DB.ExecSQL('INSERT INTO items (name) VALUES (''Discarded'')');
    DB.Rollback;
    Assert.AreEqual(1, DB.QueryInt('SELECT COUNT(*) FROM items'));
    Assert.AreEqual('Keeper', DB.QueryValue('SELECT name FROM items'));
  finally
    DB.Free;
  end;
end;

// -- Error handling -------------------------------------------------------

procedure TSQLite3Tests.TestBadSQLRaises;
var
  DB: TSQLite3;
begin
  DB := NewDb;
  try
    try
      DB.ExecSQL('THIS IS NOT VALID SQL');
      Assert.Fail('Should have raised ESQLite3Error');
    except
      on E: ESQLite3Error do
        ; // expected
    end;
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestErrorCodePopulated;
var
  DB: TSQLite3;
begin
  DB := NewDb;
  try
    try
      DB.ExecSQL('SELECT * FROM nonexistent_table');
      Assert.Fail('Should have raised');
    except
      on E: ESQLite3Error do
        Assert.IsTrue(E.ErrorCode <> 0, 'ErrorCode should be non-zero');
    end;
  finally
    DB.Free;
  end;
end;

// -- Multiple queries on same connection ----------------------------------

procedure TSQLite3Tests.TestMultipleSequentialQueries;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
begin
  DB := NewDbWithTable;
  try
    DB.ExecSQL('INSERT INTO items (name) VALUES (''X'')');
    DB.ExecSQL('INSERT INTO items (name) VALUES (''Y'')');

    Q := DB.Query('SELECT name FROM items WHERE id = 1');
    try
      Assert.IsTrue(Q.Next);
      Assert.AreEqual('X', Q.AsString(0));
    finally
      Q.Free;
    end;

    Q := DB.Query('SELECT name FROM items WHERE id = 2');
    try
      Assert.IsTrue(Q.Next);
      Assert.AreEqual('Y', Q.AsString(0));
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

// -- Type coercion --------------------------------------------------------

procedure TSQLite3Tests.TestIntStoredAsTextReadback;
var
  DB: TSQLite3;
begin
  DB := NewDb;
  try
    DB.ExecSQL('CREATE TABLE kv (key TEXT, value TEXT)');
    DB.ExecSQL('INSERT INTO kv (key, value) VALUES (:k, :v)', ['count', '42']);
    Assert.AreEqual(42, DB.QueryInt('SELECT value FROM kv'));
  finally
    DB.Free;
  end;
end;

procedure TSQLite3Tests.TestFloatPrecision;
var
  DB: TSQLite3;
  Q: TSQLite3Query;
  Val: Double;
begin
  DB := NewDb;
  try
    DB.ExecSQL('CREATE TABLE nums (v REAL)');
    DB.ExecSQL('INSERT INTO nums (v) VALUES (:v)', [1.23456789012345]);
    Q := DB.Query('SELECT v FROM nums');
    try
      Assert.IsTrue(Q.Next);
      Val := Q.AsFloat(0);
      Assert.AreEqual(Double(1.23456789012345), Val, 1E-14);
    finally
      Q.Free;
    end;
  finally
    DB.Free;
  end;
end;

end.
