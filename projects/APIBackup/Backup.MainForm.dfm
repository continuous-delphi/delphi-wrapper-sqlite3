object Main: TMain
  Left = 0
  Top = 0
  Caption = 'Demo SQLite3 Backup'
  ClientHeight = 417
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object StringGridDB: TStringGrid
    Left = 8
    Top = 8
    Width = 441
    Height = 401
    TabOrder = 0
  end
  object butAdd: TButton
    Left = 455
    Top = 50
    Width = 75
    Height = 25
    Caption = 'Add'
    TabOrder = 2
    OnClick = butAddClick
  end
  object edtTodo: TEdit
    Left = 455
    Top = 21
    Width = 161
    Height = 23
    TabOrder = 1
  end
  object butBackup: TButton
    Left = 455
    Top = 353
    Width = 75
    Height = 25
    Caption = 'Backup'
    TabOrder = 3
    OnClick = butBackupClick
  end
  object butRestore: TButton
    Left = 455
    Top = 384
    Width = 75
    Height = 25
    Caption = 'Restore'
    TabOrder = 4
    OnClick = butRestoreClick
  end
end
