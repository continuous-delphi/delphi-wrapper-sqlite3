# Changelog

## v0.1.24.0
- `ExecSQL` (no-parameter overload) now runs every statement in a multi-statement script via `sqlite3_exec`; previously only the first statement executed. Errors mid-script raise `ESQLite3Error`.
[#7](https://github.com/continuous-delphi/delphi-wrapper-sqlite3/issues/7)

## v0.1.23.0
- Add `Blob(TBytes)` factory to bind BLOB parameters through `array of const`; empty `TBytes` binds a zero-length BLOB (distinct from NULL)
[#6](https://github.com/continuous-delphi/delphi-wrapper-sqlite3/issues/6)
