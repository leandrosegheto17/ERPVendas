unit ERPV.Relatorios.PedidoLayout;

(*
  T46 (Lote 11) - Layout ReportBuilder "Confirmacao de Pedido" (desenhado no
  Report Designer pelo usuario; Bloqueio 004). Bandas: cabecalho (venda +
  cliente + titulos de coluna), detalhe (1 linha por item), resumo (total) e
  rodape. Alimentado pelo DataSet de T45 (11 colunas, nomes identicos). O
  mtPedido e so o dataset de DESENHO (dados ficticios); em execucao use
  AtribuirDados(RelatorioDataSet(Id)).

  ROTEIRO T46 NA IDE (compilacao/execucao pendentes do usuario):
  1. Compilar o projeto; a unit ja esta no .dpr/.dproj.
  2. Com uma venda de 2+ itens: Ds := Repo.RelatorioDataSet(Id);
     DM := TDMPedidoLayout.Create(nil); DM.AtribuirDados(Ds); DM.Visualizar;
     (liberar Ds e DM depois).
  3. Conferir no preview, contra SELECT direto no banco: numero, data, status,
     cliente, CPF/CNPJ, e-mail, cada item (descricao/qtd/preco/subtotal) e o
     total. Sem texto cortado (e-mail, descricao longa) nem colunas sobrepostas.
  4. Venda inexistente (DataSet vazio): o preview nao deve estourar excecao.
  A faixa "Demo Copy" e a marca d'agua do trial (T67), esperada.
*)

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, ppVar, ppCtrls, ppPrnabl, ppClass, ppBands, ppCache,
  ppDesignLayer, ppParameter, ppProd, ppReport, ppDB, ppComm, ppRelatv,
  ppDBPipe, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client;

type
  TDMPedidoLayout = class(TDataModule)
    mtPedido: TFDMemTable;
    mtPedidoVENDA_ID: TIntegerField;
    mtPedidoDATA_VENDA: TDateTimeField;
    mtPedidoSTATUS: TStringField;
    mtPedidoVALOR_TOTAL: TCurrencyField;
    mtPedidoCLIENTE_NOME: TStringField;
    mtPedidoCLIENTE_CPF_CNPJ: TStringField;
    mtPedidoCLIENTE_EMAIL: TStringField;
    mtPedidoPRODUTO_DESCRICAO: TStringField;
    mtPedidoQUANTIDADE: TIntegerField;
    mtPedidoPRECO_UNITARIO: TCurrencyField;
    mtPedidoSUBTOTAL: TCurrencyField;
    dsPedido: TDataSource;
    plPedido: TppDBPipeline;
    rptPedido: TppReport;
    ppParameterList1: TppParameterList;
    ppDesignLayers1: TppDesignLayers;
    ppDesignLayer1: TppDesignLayer;
    ppHeaderBand1: TppHeaderBand;
    ppDetailBand1: TppDetailBand;
    ppFooterBand1: TppFooterBand;
    ppSummaryBand1: TppSummaryBand;
    ppLabel1: TppLabel;
    ppDBText1: TppDBText;
    ppDBText2: TppDBText;
    ppDBText3: TppDBText;
    ppDBText4: TppDBText;
    ppDBText5: TppDBText;
    ppDBText6: TppDBText;
    ppLabel2: TppLabel;
    ppLabel3: TppLabel;
    ppLabel4: TppLabel;
    ppLabel5: TppLabel;
    ppDBText7: TppDBText;
    ppDBText8: TppDBText;
    ppDBText9: TppDBText;
    ppDBText10: TppDBText;
    ppDBText11: TppDBText;
    ppSystemVariable1: TppSystemVariable;
    ppSystemVariable2: TppSystemVariable;
  public
    /// <summary>Liga o layout ao DataSet do relatorio (T45,
    /// IVendaRepository.RelatorioDataSet). O DataSet segue sendo do chamador.
    /// Colunas esperadas: as 11 do RelatorioDataSet (nomes identicos).</summary>
    procedure AtribuirDados(ADataSet: TDataSet);
    /// <summary>Preview em tela (conferencia manual do T46 contra o banco).</summary>
    procedure Visualizar;
  end;

var
  DMPedidoLayout: TDMPedidoLayout;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

procedure TDMPedidoLayout.AtribuirDados(ADataSet: TDataSet);
begin
  dsPedido.DataSet := ADataSet;
end;

procedure TDMPedidoLayout.Visualizar;
begin
  rptPedido.DeviceType := 'Screen';
  rptPedido.Print;
end;

end.
