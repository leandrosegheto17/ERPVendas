object DMPedidoLayout: TDMPedidoLayout
  Height = 480
  Width = 640
  object mtPedido: TFDMemTable
    Active = True
    FieldDefs = <
      item
        Name = 'VENDA_ID'
        DataType = ftInteger
      end
      item
        Name = 'DATA_VENDA'
        DataType = ftDateTime
      end
      item
        Name = 'STATUS'
        DataType = ftString
        Size = 20
      end
      item
        Name = 'VALOR_TOTAL'
        DataType = ftCurrency
        Precision = 19
      end
      item
        Name = 'CLIENTE_NOME'
        DataType = ftString
        Size = 100
      end
      item
        Name = 'CLIENTE_CPF_CNPJ'
        DataType = ftString
        Size = 18
      end
      item
        Name = 'CLIENTE_EMAIL'
        DataType = ftString
        Size = 100
      end
      item
        Name = 'PRODUTO_DESCRICAO'
        DataType = ftString
        Size = 100
      end
      item
        Name = 'QUANTIDADE'
        DataType = ftInteger
      end
      item
        Name = 'PRECO_UNITARIO'
        DataType = ftCurrency
        Precision = 19
      end
      item
        Name = 'SUBTOTAL'
        DataType = ftCurrency
        Precision = 19
      end>
    IndexDefs = <>
    FetchOptions.AssignedValues = [evMode]
    FetchOptions.Mode = fmAll
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvCheckRequired, uvAutoCommitUpdates]
    UpdateOptions.CheckRequired = False
    UpdateOptions.AutoCommitUpdates = True
    StoreDefs = True
    Left = 112
    Top = 48
    object mtPedidoVENDA_ID: TIntegerField
      FieldName = 'VENDA_ID'
    end
    object mtPedidoDATA_VENDA: TDateTimeField
      FieldName = 'DATA_VENDA'
    end
    object mtPedidoSTATUS: TStringField
      FieldName = 'STATUS'
    end
    object mtPedidoVALOR_TOTAL: TCurrencyField
      FieldName = 'VALOR_TOTAL'
    end
    object mtPedidoCLIENTE_NOME: TStringField
      FieldName = 'CLIENTE_NOME'
      Size = 100
    end
    object mtPedidoCLIENTE_CPF_CNPJ: TStringField
      FieldName = 'CLIENTE_CPF_CNPJ'
      Size = 18
    end
    object mtPedidoCLIENTE_EMAIL: TStringField
      FieldName = 'CLIENTE_EMAIL'
      Size = 100
    end
    object mtPedidoPRODUTO_DESCRICAO: TStringField
      FieldName = 'PRODUTO_DESCRICAO'
      Size = 100
    end
    object mtPedidoQUANTIDADE: TIntegerField
      FieldName = 'QUANTIDADE'
    end
    object mtPedidoPRECO_UNITARIO: TCurrencyField
      FieldName = 'PRECO_UNITARIO'
    end
    object mtPedidoSUBTOTAL: TCurrencyField
      FieldName = 'SUBTOTAL'
    end
  end
  object dsPedido: TDataSource
    DataSet = mtPedido
    Left = 184
    Top = 48
  end
  object plPedido: TppDBPipeline
    DataSource = dsPedido
    UserName = 'plPedido'
    Left = 256
    Top = 48
    object ppDBPipeline1ppField1: TppField
      Alignment = taRightJustify
      FieldAlias = 'VENDA_ID'
      FieldName = 'VENDA_ID'
      FieldLength = 0
      DataType = dtInteger
      DisplayWidth = 10
      Position = 0
    end
    object ppDBPipeline1ppField2: TppField
      FieldAlias = 'DATA_VENDA'
      FieldName = 'DATA_VENDA'
      FieldLength = 0
      DataType = dtDateTime
      DisplayWidth = 18
      Position = 1
    end
    object ppDBPipeline1ppField3: TppField
      FieldAlias = 'STATUS'
      FieldName = 'STATUS'
      FieldLength = 20
      DisplayWidth = 20
      Position = 2
    end
    object ppDBPipeline1ppField4: TppField
      FieldAlias = 'VALOR_TOTAL'
      FieldName = 'VALOR_TOTAL'
      FieldLength = 0
      DataType = dtCurrency
      DisplayWidth = 10
      Position = 3
    end
    object ppDBPipeline1ppField5: TppField
      FieldAlias = 'CLIENTE_NOME'
      FieldName = 'CLIENTE_NOME'
      FieldLength = 100
      DisplayWidth = 100
      Position = 4
    end
    object ppDBPipeline1ppField6: TppField
      FieldAlias = 'CLIENTE_CPF_CNPJ'
      FieldName = 'CLIENTE_CPF_CNPJ'
      FieldLength = 18
      DisplayWidth = 18
      Position = 5
    end
    object ppDBPipeline1ppField7: TppField
      FieldAlias = 'CLIENTE_EMAIL'
      FieldName = 'CLIENTE_EMAIL'
      FieldLength = 100
      DisplayWidth = 100
      Position = 6
    end
    object ppDBPipeline1ppField8: TppField
      FieldAlias = 'PRODUTO_DESCRICAO'
      FieldName = 'PRODUTO_DESCRICAO'
      FieldLength = 100
      DisplayWidth = 100
      Position = 7
    end
    object ppDBPipeline1ppField9: TppField
      Alignment = taRightJustify
      FieldAlias = 'QUANTIDADE'
      FieldName = 'QUANTIDADE'
      FieldLength = 0
      DataType = dtInteger
      DisplayWidth = 10
      Position = 8
    end
    object ppDBPipeline1ppField10: TppField
      FieldAlias = 'PRECO_UNITARIO'
      FieldName = 'PRECO_UNITARIO'
      FieldLength = 0
      DataType = dtCurrency
      DisplayWidth = 10
      Position = 9
    end
    object ppDBPipeline1ppField11: TppField
      FieldAlias = 'SUBTOTAL'
      FieldName = 'SUBTOTAL'
      FieldLength = 0
      DataType = dtCurrency
      DisplayWidth = 10
      Position = 10
    end
  end
  object rptPedido: TppReport
    AutoStop = False
    DataPipeline = plPedido
    PrinterSetup.BinName = 'Default'
    PrinterSetup.DocumentName = 'Report'
    PrinterSetup.PaperName = 'A4'
    PrinterSetup.PrinterName = 'Default'
    PrinterSetup.SaveDeviceSettings = False
    PrinterSetup.mmMarginBottom = 6350
    PrinterSetup.mmMarginLeft = 6350
    PrinterSetup.mmMarginRight = 6350
    PrinterSetup.mmMarginTop = 6350
    PrinterSetup.mmPaperHeight = 297000
    PrinterSetup.mmPaperWidth = 210000
    PrinterSetup.PaperSize = 9
    ArchiveFileName = '($MyDocuments)\ReportArchive.raf'
    DeviceType = 'Screen'
    DefaultFileDeviceType = 'PDF'
    EmailSettings.ReportFormat = 'PDF'
    EmailSettings.ConnectionSettings.MailService = 'SMTP'
    EmailSettings.ConnectionSettings.WebMail.GmailSettings.OAuth2.AuthStorage = [oasAccessToken, oasRefreshToken, oasEncryptTokens]
    EmailSettings.ConnectionSettings.WebMail.GmailSettings.OAuth2.RedirectURI = 'http://localhost'
    EmailSettings.ConnectionSettings.WebMail.GmailSettings.OAuth2.RedirectPort = 0
    EmailSettings.ConnectionSettings.WebMail.GmailSettings.OAuth2.RefreshTokenLifeSpan = 365
    EmailSettings.ConnectionSettings.WebMail.Outlook365Settings.OAuth2.AuthStorage = [oasAccessToken, oasRefreshToken, oasEncryptTokens]
    EmailSettings.ConnectionSettings.WebMail.Outlook365Settings.OAuth2.RedirectURI = 'http://localhost'
    EmailSettings.ConnectionSettings.WebMail.Outlook365Settings.OAuth2.RedirectPort = 0
    EmailSettings.ConnectionSettings.WebMail.Outlook365Settings.OAuth2.RefreshTokenLifeSpan = 365
    EmailSettings.ConnectionSettings.EnableMultiPlugin = False
    EmailSettings.ConnectionSettings.ConnectionStatusInfo = [csiStatusBar]
    LanguageID = 'Default'
    OpenFile = False
    OutlineSettings.CreateNode = True
    OutlineSettings.CreatePageNodes = True
    OutlineSettings.Enabled = True
    OutlineSettings.Visible = True
    ThumbnailSettings.Enabled = True
    ThumbnailSettings.Visible = True
    ThumbnailSettings.DeadSpace = 30
    ThumbnailSettings.PageHighlight.Width = 3
    ThumbnailSettings.ThumbnailSize = tsSmall
    PDFSettings.EmbedFontOptions = [efUseSubset]
    PDFSettings.EncryptSettings.AllowCopy = True
    PDFSettings.EncryptSettings.AllowInteract = True
    PDFSettings.EncryptSettings.AllowModify = True
    PDFSettings.EncryptSettings.AllowPrint = True
    PDFSettings.EncryptSettings.AllowExtract = True
    PDFSettings.EncryptSettings.AllowAssemble = True
    PDFSettings.EncryptSettings.AllowQualityPrint = True
    PDFSettings.EncryptSettings.Enabled = False
    PDFSettings.EncryptSettings.KeyLength = kl40Bit
    PDFSettings.EncryptSettings.EncryptionType = etRC4
    PDFSettings.DigitalSignatureSettings.SignPDF = False
    PDFSettings.FontEncoding = feAnsi
    PDFSettings.ImageCompressionLevel = 25
    PDFSettings.PDFAFormat = pafNone
    PDFSettings.Layers = False
    PDFSettings.Outline = False
    PreviewFormSettings.PageBorder.mmPadding = 0
    RTFSettings.AppName = 'ReportBuilder'
    RTFSettings.Author = 'ReportBuilder'
    RTFSettings.DefaultFont.Charset = DEFAULT_CHARSET
    RTFSettings.DefaultFont.Color = clWindowText
    RTFSettings.DefaultFont.Height = -13
    RTFSettings.DefaultFont.Name = 'Arial'
    RTFSettings.DefaultFont.Style = []
    RTFSettings.Title = 'Report'
    TextFileName = '($MyDocuments)\Report.pdf'
    TextSearchSettings.DefaultString = '<FindText>'
    TextSearchSettings.Enabled = True
    XLSSettings.AppName = 'ReportBuilder'
    XLSSettings.Author = 'ReportBuilder'
    XLSSettings.Subject = 'Report'
    XLSSettings.Title = 'Report'
    XLSSettings.WorksheetName = 'Report'
    CloudDriveSettings.DropBoxSettings.OAuth2.AuthStorage = [oasAccessToken, oasRefreshToken, oasEncryptTokens]
    CloudDriveSettings.DropBoxSettings.OAuth2.RedirectURI = 'http://localhost'
    CloudDriveSettings.DropBoxSettings.OAuth2.RedirectPort = 0
    CloudDriveSettings.DropBoxSettings.OAuth2.RefreshTokenLifeSpan = 365
    CloudDriveSettings.DropBoxSettings.DirectorySupport = True
    CloudDriveSettings.DropBoxSettings.SharedResources = True
    CloudDriveSettings.GoogleDriveSettings.OAuth2.AuthStorage = [oasAccessToken, oasRefreshToken, oasEncryptTokens]
    CloudDriveSettings.GoogleDriveSettings.OAuth2.RedirectURI = 'http://localhost'
    CloudDriveSettings.GoogleDriveSettings.OAuth2.RedirectPort = 0
    CloudDriveSettings.GoogleDriveSettings.OAuth2.RefreshTokenLifeSpan = 365
    CloudDriveSettings.GoogleDriveSettings.DirectorySupport = False
    CloudDriveSettings.GoogleDriveSettings.SharedResources = False
    CloudDriveSettings.OneDriveSettings.OAuth2.AuthStorage = [oasAccessToken, oasRefreshToken, oasEncryptTokens]
    CloudDriveSettings.OneDriveSettings.OAuth2.RedirectURI = 'http://localhost'
    CloudDriveSettings.OneDriveSettings.OAuth2.RedirectPort = 0
    CloudDriveSettings.OneDriveSettings.OAuth2.RefreshTokenLifeSpan = 365
    CloudDriveSettings.OneDriveSettings.DirectorySupport = True
    CloudDriveSettings.OneDriveSettings.SharedResources = True
    Left = 256
    Top = 112
    Version = '23.04'
    mmColumnWidth = 0
    DataPipelineName = 'plPedido'
    object ppHeaderBand1: TppHeaderBand
      Border.mmPadding = 0
      mmBottomOffset = 0
      mmHeight = 31750
      mmPrintPosition = 0
      object ppLabel1: TppLabel
        DesignLayer = ppDesignLayer1
        UserName = 'Label1'
        Border.mmPadding = 0
        Caption = 'Confirma'#231#227'o de Pedido'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        FormFieldSettings.FormSubmitInfo.SubmitMethod = fstPost
        FormFieldSettings.FormFieldType = fftNone
        Transparent = True
        mmHeight = 4233
        mmLeft = 3704
        mmTop = 1323
        mmWidth = 35454
        BandType = 0
        LayerName = Foreground
      end
      object ppDBText1: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText1'
        Border.mmPadding = 0
        DataField = 'VENDA_ID'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 4233
        mmTop = 7673
        mmWidth = 17198
        BandType = 0
        LayerName = Foreground
      end
      object ppDBText2: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText2'
        Border.mmPadding = 0
        DataField = 'DATA_VENDA'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        OnGetText = DataHoraGetText
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 46302
        mmTop = 7144
        mmWidth = 40000
        BandType = 0
        LayerName = Foreground
      end
      object ppDBText3: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText3'
        Border.mmPadding = 0
        DataField = 'STATUS'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        DataPipelineName = 'plPedido'
        mmHeight = 4234
        mmLeft = 94986
        mmTop = 7408
        mmWidth = 40000
        BandType = 0
        LayerName = Foreground
      end
      object ppDBText4: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText4'
        Border.mmPadding = 0
        DataField = 'CLIENTE_NOME'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 4233
        mmTop = 13229
        mmWidth = 192000
        BandType = 0
        LayerName = Foreground
      end
      object ppDBText5: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText5'
        Border.mmPadding = 0
        DataField = 'CLIENTE_CPF_CNPJ'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        DataPipelineName = 'plPedido'
        mmHeight = 4234
        mmLeft = 4233
        mmTop = 18521
        mmWidth = 35000
        BandType = 0
        LayerName = Foreground
      end
      object ppDBText6: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText6'
        Border.mmPadding = 0
        DataField = 'CLIENTE_EMAIL'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 42000
        mmTop = 18521
        mmWidth = 150000
        BandType = 0
        LayerName = Foreground
      end
      object ppLabel2: TppLabel
        DesignLayer = ppDesignLayer1
        UserName = 'Label2'
        Border.mmPadding = 0
        Caption = 'Produto'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        FormFieldSettings.FormSubmitInfo.SubmitMethod = fstPost
        FormFieldSettings.FormFieldType = fftNone
        Transparent = True
        mmHeight = 4233
        mmLeft = 4233
        mmTop = 26988
        mmWidth = 11907
        BandType = 0
        LayerName = Foreground
      end
      object ppLabel3: TppLabel
        DesignLayer = ppDesignLayer1
        UserName = 'Label3'
        Border.mmPadding = 0
        Caption = 'Quantidade'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        FormFieldSettings.FormSubmitInfo.SubmitMethod = fstPost
        FormFieldSettings.FormFieldType = fftNone
        Transparent = True
        mmHeight = 4234
        mmLeft = 68263
        mmTop = 26723
        mmWidth = 17462
        BandType = 0
        LayerName = Foreground
      end
      object ppLabel4: TppLabel
        DesignLayer = ppDesignLayer1
        UserName = 'Label4'
        Border.mmPadding = 0
        Caption = 'Pre'#231'o Unit'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        FormFieldSettings.FormSubmitInfo.SubmitMethod = fstPost
        FormFieldSettings.FormFieldType = fftNone
        Transparent = True
        mmHeight = 4233
        mmLeft = 128588
        mmTop = 26988
        mmWidth = 16139
        BandType = 0
        LayerName = Foreground
      end
      object ppLabel5: TppLabel
        DesignLayer = ppDesignLayer1
        UserName = 'Label5'
        Border.mmPadding = 0
        Caption = 'Subtotal'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        FormFieldSettings.FormSubmitInfo.SubmitMethod = fstPost
        FormFieldSettings.FormFieldType = fftNone
        Transparent = True
        mmHeight = 4233
        mmLeft = 173832
        mmTop = 26988
        mmWidth = 12700
        BandType = 0
        LayerName = Foreground
      end
    end
    object ppDetailBand1: TppDetailBand
      Border.mmPadding = 0
      mmBottomOffset = 0
      mmHeight = 7673
      mmPrintPosition = 0
      object ppDBText7: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText7'
        Border.mmPadding = 0
        DataField = 'PRODUTO_DESCRICAO'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        WordWrap = True
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 4498
        mmTop = 1323
        mmWidth = 59267
        BandType = 4
        LayerName = Foreground
      end
      object ppDBText8: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText8'
        Border.mmPadding = 0
        DataField = 'QUANTIDADE'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 68263
        mmTop = 1323
        mmWidth = 17198
        BandType = 4
        LayerName = Foreground
      end
      object ppDBText9: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText9'
        Border.mmPadding = 0
        DataField = 'PRECO_UNITARIO'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        OnGetText = MoedaGetText
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 128588
        mmTop = 1323
        mmWidth = 17198
        BandType = 4
        LayerName = Foreground
      end
      object ppDBText10: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText10'
        Border.mmPadding = 0
        DataField = 'SUBTOTAL'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        OnGetText = MoedaGetText
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 173832
        mmTop = 1323
        mmWidth = 17198
        BandType = 4
        LayerName = Foreground
      end
    end
    object ppFooterBand1: TppFooterBand
      Border.mmPadding = 0
      mmBottomOffset = 0
      mmHeight = 9260
      mmPrintPosition = 0
      object ppSystemVariable1: TppSystemVariable
        DesignLayer = ppDesignLayer1
        UserName = 'SystemVariable1'
        Border.mmPadding = 0
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        mmHeight = 4234
        mmLeft = 4763
        mmTop = 2381
        mmWidth = 16933
        BandType = 8
        LayerName = Foreground
      end
      object ppSystemVariable2: TppSystemVariable
        DesignLayer = ppDesignLayer1
        UserName = 'SystemVariable2'
        Border.mmPadding = 0
        VarType = vtPageCount
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        mmHeight = 4234
        mmLeft = 173832
        mmTop = 2381
        mmWidth = 1852
        BandType = 8
        LayerName = Foreground
      end
    end
    object ppSummaryBand1: TppSummaryBand
      Border.mmPadding = 0
      mmBottomOffset = 0
      mmHeight = 7408
      mmPrintPosition = 0
      object ppDBText11: TppDBText
        DesignLayer = ppDesignLayer1
        UserName = 'DBText11'
        Border.mmPadding = 0
        DataField = 'VALOR_TOTAL'
        DataPipeline = plPedido
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Name = 'Arial'
        Font.Size = 10
        Font.Style = []
        Transparent = True
        OnGetText = MoedaGetText
        DataPipelineName = 'plPedido'
        mmHeight = 4233
        mmLeft = 173567
        mmTop = 1588
        mmWidth = 17198
        BandType = 7
        LayerName = Foreground
      end
    end
    object ppDesignLayers1: TppDesignLayers
      object ppDesignLayer1: TppDesignLayer
        UserName = 'Foreground'
        LayerType = ltBanded
        Index = 0
      end
    end
    object ppParameterList1: TppParameterList
    end
  end
end
