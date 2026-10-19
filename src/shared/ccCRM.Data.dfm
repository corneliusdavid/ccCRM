object dmccCRM: TdmccCRM
  Height = 220
  Width = 840
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
  object qTypes: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT TYPE_ID, NAME, SORT_ORDER FROM CUSTOMER_TYPE'
      'ORDER BY SORT_ORDER, NAME')
    Left = 340
    Top = 24
  end
  object qStatuses: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT STATUS_ID, NAME, SORT_ORDER FROM CUSTOMER_STATUS'
      'ORDER BY SORT_ORDER, NAME')
    Left = 340
    Top = 80
  end
  object qCustomers: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT C.WAVE_ID, C.NAME, C.FIRST_NAME, C.LAST_NAME, C.EMAIL, C.PHONE, C.MOBILE,'
      '  C.CITY, C.STATE_CODE, C.TYPE_ID, T.NAME AS TYPE_NAME, C.STATUS_ID,'
      '  S.NAME AS STATUS_NAME, C.USER_COUNT, C.IN_WAVE'
      'FROM CUSTOMER C'
      'LEFT JOIN CUSTOMER_TYPE T ON T.TYPE_ID = C.TYPE_ID'
      'LEFT JOIN CUSTOMER_STATUS S ON S.STATUS_ID = C.STATUS_ID'
      'WHERE (CAST(:Q AS VARCHAR(100)) IS NULL'
      '    OR C.NAME CONTAINING :Q OR C.FIRST_NAME CONTAINING :Q'
      '    OR C.LAST_NAME CONTAINING :Q OR C.EMAIL CONTAINING :Q'
      '    OR C.PHONE CONTAINING :Q OR C.MOBILE CONTAINING :Q'
      '    OR C.AD_GROUP CONTAINING :Q OR C.CITY CONTAINING :Q'
      '    OR EXISTS (SELECT 1 FROM CONTACT K WHERE K.WAVE_ID = C.WAVE_ID'
      '        AND (K.NAME CONTAINING :Q OR K.EMAIL CONTAINING :Q OR K.PHONE CONTAINING :Q)))'
      '  AND (CAST(:TYPE_ID AS INTEGER) IS NULL OR C.TYPE_ID = :TYPE_ID'
      '    OR (:TYPE_ID = 0 AND C.TYPE_ID IS NULL))'
      '  AND (CAST(:STATUS_ID AS INTEGER) IS NULL OR C.STATUS_ID = :STATUS_ID'
      '    OR (:STATUS_ID = 0 AND C.STATUS_ID IS NULL))'
      'ORDER BY C.NAME')
    Left = 340
    Top = 136
    ParamData = <
      item
        Name = 'Q'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'TYPE_ID'
        DataType = ftInteger
        ParamType = ptInput
      end
      item
        Name = 'STATUS_ID'
        DataType = ftInteger
        ParamType = ptInput
      end>
  end
  object qCustomer: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT C.WAVE_ID, C.NAME, C.FIRST_NAME, C.LAST_NAME, C.EMAIL, C.PHONE, C.MOBILE,'
      '  C.WEBSITE, C.ADDRESS1, C.ADDRESS2, C.CITY, C.STATE_CODE, C.POSTAL_CODE,'
      '  C.IN_WAVE, C.SYNCED_AT, C.TYPE_ID, T.NAME AS TYPE_NAME, C.STATUS_ID,'
      '  S.NAME AS STATUS_NAME, C.AD_GROUP, C.USER_COUNT, C.NOTES'
      'FROM CUSTOMER C'
      'LEFT JOIN CUSTOMER_TYPE T ON T.TYPE_ID = C.TYPE_ID'
      'LEFT JOIN CUSTOMER_STATUS S ON S.STATUS_ID = C.STATUS_ID'
      'WHERE C.WAVE_ID = :WAVE_ID')
    Left = 440
    Top = 24
    ParamData = <
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object qContacts: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT CONTACT_ID, WAVE_ID, NAME, EMAIL, PHONE, JOB_TITLE'
      'FROM CONTACT WHERE WAVE_ID = :WAVE_ID ORDER BY NAME')
    Left = 440
    Top = 80
    ParamData = <
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object qLog: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT LOG_ID, WAVE_ID, EVENT_DATE, LOGGED_AT, LOGGED_BY, ENTRY_SOURCE,'
      '  FIELD_NAME, SUMMARY'
      'FROM CUSTOMER_LOG WHERE WAVE_ID = :WAVE_ID'
      'ORDER BY EVENT_DATE DESC, LOG_ID DESC')
    Left = 440
    Top = 136
    ParamData = <
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object qEmails: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'SELECT DISTINCT EMAIL FROM V_EMAIL_LIST'
      'WHERE (CAST(:TYPE_NAME AS VARCHAR(40)) IS NULL OR TYPE_NAME = :TYPE_NAME)'
      '  AND (CAST(:STATUS_NAME AS VARCHAR(40)) IS NULL OR STATUS_NAME = :STATUS_NAME)'
      'ORDER BY EMAIL')
    Left = 540
    Top = 24
    ParamData = <
      item
        Name = 'TYPE_NAME'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'STATUS_NAME'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object cmdUpdateCustomer: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'UPDATE CUSTOMER SET TYPE_ID = :TYPE_ID, STATUS_ID = :STATUS_ID,'
      '  AD_GROUP = :AD_GROUP, USER_COUNT = :USER_COUNT, NOTES = :NOTES'
      'WHERE WAVE_ID = :WAVE_ID')
    Left = 540
    Top = 80
    ParamData = <
      item
        Name = 'TYPE_ID'
        DataType = ftInteger
        ParamType = ptInput
      end
      item
        Name = 'STATUS_ID'
        DataType = ftInteger
        ParamType = ptInput
      end
      item
        Name = 'AD_GROUP'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'USER_COUNT'
        DataType = ftInteger
        ParamType = ptInput
      end
      item
        Name = 'NOTES'
        DataType = ftWideMemo
        ParamType = ptInput
      end
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object cmdAddContact: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'INSERT INTO CONTACT (WAVE_ID, NAME, EMAIL, PHONE, JOB_TITLE)'
      'VALUES (:WAVE_ID, :NAME, :EMAIL, :PHONE, :JOB_TITLE)')
    Left = 540
    Top = 136
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
        Name = 'JOB_TITLE'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object cmdUpdateContact: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'UPDATE CONTACT SET NAME = :NAME, EMAIL = :EMAIL, PHONE = :PHONE,'
      '  JOB_TITLE = :JOB_TITLE'
      'WHERE CONTACT_ID = :CONTACT_ID')
    Left = 640
    Top = 24
    ParamData = <
      item
        Name = 'NAME'
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
        Name = 'JOB_TITLE'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'CONTACT_ID'
        DataType = ftInteger
        ParamType = ptInput
      end>
  end
  object cmdDeleteContact: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'DELETE FROM CONTACT WHERE CONTACT_ID = :CONTACT_ID')
    Left = 640
    Top = 80
    ParamData = <
      item
        Name = 'CONTACT_ID'
        DataType = ftInteger
        ParamType = ptInput
      end>
  end
  object cmdAddLog: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'INSERT INTO CUSTOMER_LOG (WAVE_ID, EVENT_DATE, ENTRY_SOURCE, SUMMARY)'
      'VALUES (:WAVE_ID, :EVENT_DATE, '#39'M'#39', :SUMMARY)')
    Left = 640
    Top = 136
    ParamData = <
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'EVENT_DATE'
        DataType = ftDate
        ParamType = ptInput
      end
      item
        Name = 'SUMMARY'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object cmdUpdateLog: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'UPDATE CUSTOMER_LOG SET EVENT_DATE = :EVENT_DATE, SUMMARY = :SUMMARY'
      'WHERE LOG_ID = :LOG_ID AND ENTRY_SOURCE = '#39'M'#39)
    Left = 740
    Top = 24
    ParamData = <
      item
        Name = 'EVENT_DATE'
        DataType = ftDate
        ParamType = ptInput
      end
      item
        Name = 'SUMMARY'
        DataType = ftWideString
        ParamType = ptInput
      end
      item
        Name = 'LOG_ID'
        DataType = ftInteger
        ParamType = ptInput
      end>
  end
  object cmdDeleteLog: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'DELETE FROM CUSTOMER_LOG WHERE LOG_ID = :LOG_ID AND ENTRY_SOURCE = '#39'M'#39)
    Left = 740
    Top = 80
    ParamData = <
      item
        Name = 'LOG_ID'
        DataType = ftInteger
        ParamType = ptInput
      end>
  end
  object cmdDeleteCustomerContacts: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'DELETE FROM CONTACT WHERE WAVE_ID = :WAVE_ID')
    Left = 740
    Top = 136
    ParamData = <
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object cmdDeleteCustomerLog: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'DELETE FROM CUSTOMER_LOG WHERE WAVE_ID = :WAVE_ID')
    Left = 840
    Top = 24
    ParamData = <
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
  object cmdDeleteCustomer: TFDQuery
    Connection = Conn
    SQL.Strings = (
      'DELETE FROM CUSTOMER WHERE WAVE_ID = :WAVE_ID AND NOT IN_WAVE')
    Left = 840
    Top = 80
    ParamData = <
      item
        Name = 'WAVE_ID'
        DataType = ftWideString
        ParamType = ptInput
      end>
  end
end
