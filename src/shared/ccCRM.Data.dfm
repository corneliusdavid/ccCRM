object dmccCRM: TdmccCRM
  Height = 220
  Width = 330
  object Conn: TFDConnection
    Params.Strings = (
      'DriverID=FB'
      'CharacterSet=UTF8'
      'User_Name=sysdba'
      'Password=masterkey')
    LoginPrompt = False
    Left = 40
    Top = 24
  end
  object FBDriver: TFDPhysFBDriverLink
    Left = 40
    Top = 80
  end
  object qWaveIds: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT WAVE_ID FROM CUSTOMER')
    Left = 140
    Top = 24
  end
  object qCount: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT COUNT(*) FROM CUSTOMER')
    Left = 140
    Top = 80
  end
  object cmdUpsert: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'UPDATE OR INSERT INTO CUSTOMER'
      
        '  (WAVE_ID, NAME, FIRST_NAME, LAST_NAME, EMAIL, PHONE, MOBILE, W' +
        'EBSITE,'
      
        '   ADDRESS1, ADDRESS2, CITY, STATE_CODE, POSTAL_CODE, IN_WAVE, S' +
        'YNCED_AT)'
      'VALUES'
      
        '  (:WAVE_ID, :NAME, :FIRST_NAME, :LAST_NAME, :EMAIL, :PHONE, :MO' +
        'BILE, :WEBSITE,'
      
        '   :ADDRESS1, :ADDRESS2, :CITY, :STATE_CODE, :POSTAL_CODE, TRUE,' +
        ' :SYNCED_AT)'
      'MATCHING (WAVE_ID)')
    Left = 240
    Top = 24
    ParamData = <
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'NAME'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'FIRST_NAME'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'LAST_NAME'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'EMAIL'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'PHONE'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'MOBILE'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'WEBSITE'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'ADDRESS1'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'ADDRESS2'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'CITY'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'STATE_CODE'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'POSTAL_CODE'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'SYNCED_AT'
        DataType = ftDateTime
        ParamType = ptInput
      end>
  end
  object cmdMarkMissing: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'UPDATE CUSTOMER SET IN_WAVE = FALSE'
      'WHERE IN_WAVE AND (SYNCED_AT IS NULL OR SYNCED_AT < :SYNCED_AT)')
    Left = 240
    Top = 80
    ParamData = <
      item
        Name = 'SYNCED_AT'
        DataType = ftDateTime
        ParamType = ptInput
      end>
  end
end
