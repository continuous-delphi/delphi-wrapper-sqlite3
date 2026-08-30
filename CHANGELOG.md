# Changelog

## v0.1.23.0
- Add `Blob(TBytes)` factory to bind BLOB parameters through `array of const`; empty `TBytes` binds a zero-length BLOB (distinct from NULL)
[#6](https://github.com/continuous-delphi/delphi-wrapper-sqlite3/issues/6)
