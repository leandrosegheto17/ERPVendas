unit ERPV.Negocio.VendaService;

(*
  T27 - Regras de negocio de Venda (CRUD + validacoes, RF-07/08, RN-01/03).
  Camada Negocio: so depende de interfaces do Dominio e do Core.
  T28: total = Soma(qtd x preco) recalculado; preco do item e snapshot do
  produto (valores vindos do chamador sao ignorados).
  T29: so venda Pendente e alteravel/excluivel (status lido do banco).
*)

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  ERPV.Core.Erros,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Cliente,
  ERPV.Dominio.Produto,
  ERPV.Dominio.Venda,
  ERPV.Dominio.VendaItem,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IClienteRepository,
  ERPV.Dominio.Contratos.IProdutoRepository,
  ERPV.Dominio.Contratos.IFilaRepository;

type
  TVendaService = class
  private
    FVendaRepositorio: IVendaRepository;
    FClienteRepositorio: IClienteRepository;
    FProdutoRepositorio: IProdutoRepository;
    FFilaRepositorio: IFilaRepository;
    procedure Validar(const AVenda: TVenda; const AAtual: TVenda);
    procedure ExigirPendente(AId: Integer; out AAtual: TVenda);
    procedure AplicarPrecosETotal(const AVenda: TVenda; const AAtual: TVenda);
  public
    constructor Create(const AVendaRepositorio: IVendaRepository;
      const AClienteRepositorio: IClienteRepository;
      const AProdutoRepositorio: IProdutoRepository;
      const AFilaRepositorio: IFilaRepository = nil);

    /// <summary>T53 (UX 4.2): True se ha QUITACAO/CANCELAMENTO pendente na fila
    /// para a venda (edicao/exclusao bloqueadas). False sem fila injetada.</summary>
    function TemPendenciaFila(AId: Integer): Boolean;

    /// <summary>Valida e inclui (Id = 0, nasce Pendente) ou altera (Id > 0).
    /// Devolve o Id. A entidade continua sendo do chamador.</summary>
    /// <exception cref="EValidacao">Violacao de regra (Campo preenchido).</exception>
    function Salvar(const AVenda: TVenda): Integer;
    /// <summary>Devolve a venda (o chamador libera) ou nil.</summary>
    function Obter(AId: Integer): TVenda;
    function ListarDataSet(const AStatusFiltro: string; AClienteIdFiltro: Integer): TDataSet;
    procedure Excluir(AId: Integer);
  end;

implementation

uses
  ERPV.Negocio.PendenciaFila;

constructor TVendaService.Create(const AVendaRepositorio: IVendaRepository;
  const AClienteRepositorio: IClienteRepository;
  const AProdutoRepositorio: IProdutoRepository;
  const AFilaRepositorio: IFilaRepository);
begin
  inherited Create;
  FVendaRepositorio := AVendaRepositorio;
  FClienteRepositorio := AClienteRepositorio;
  FProdutoRepositorio := AProdutoRepositorio;
  FFilaRepositorio := AFilaRepositorio;
end;

function TVendaService.TemPendenciaFila(AId: Integer): Boolean;
begin
  Result := VendaBloqueadaPorFila(FFilaRepositorio, AId);
end;

procedure TVendaService.Validar(const AVenda: TVenda; const AAtual: TVenda);
  // RF7-02 (decisao A): em edicao, cliente/produto inativado DEPOIS da venda
  // criada e aceito se NAO foi trocado (igual ao de AAtual); escolher/trocar
  // para inativo continua recusado.
  function ProdutoJaNaVenda(AProdutoId: Integer): Boolean;
  var
    Antigo: TVendaItem;
  begin
    Result := False;
    if AAtual <> nil then
      for Antigo in AAtual.Itens do
        if Antigo.ProdutoId = AProdutoId then
          Exit(True);
  end;

var
  Cliente: TCliente;
  Produto: TProduto;
  Item: TVendaItem;
begin
  if AVenda.ClienteId <= 0 then
    raise EValidacao.CreateCampo('Cliente', 'Informe o cliente');

  Cliente := FClienteRepositorio.Obter(AVenda.ClienteId);
  try
    if Cliente = nil then
      raise EValidacao.CreateCampo('Cliente', 'Cliente não encontrado');
    if (not Cliente.Ativo) and
      not ((AAtual <> nil) and (AAtual.ClienteId = AVenda.ClienteId)) then
      raise EValidacao.CreateCampo('Cliente', 'Cliente inativo não pode receber venda');
  finally
    Cliente.Free;
  end;

  if AVenda.Itens.Count < 1 then
    raise EValidacao.CreateCampo('Itens', 'A venda deve ter ao menos um item');

  for Item in AVenda.Itens do
  begin
    if Item.Quantidade <= 0 then
      raise EValidacao.CreateCampo('Quantidade', 'A quantidade deve ser maior que zero');

    Produto := FProdutoRepositorio.Obter(Item.ProdutoId);
    try
      if Produto = nil then
        raise EValidacao.CreateCampo('Produto', 'Produto não encontrado');
      if (not Produto.Ativo) and (not ProdutoJaNaVenda(Item.ProdutoId)) then
        raise EValidacao.CreateCampo('Produto',
          Format('Produto "%s" inativo não pode ser vendido', [Produto.Descricao]));
    finally
      Produto.Free;
    end;
  end;
end;

procedure TVendaService.ExigirPendente(AId: Integer; out AAtual: TVenda);
var
  Msg: string;
  Bloqueada: Boolean;
begin
  // Status sempre lido do banco; o objeto do chamador nao e confiavel.
  AAtual := FVendaRepositorio.Obter(AId);
  if AAtual = nil then
    raise ERegraNegocio.Create('Venda não encontrada');
  if AAtual.Status <> svPendente then
  begin
    if AAtual.Status = svQuitada then
      Msg := 'Venda já quitada não pode ser alterada nem excluída'
    else
      Msg := 'Venda cancelada não pode ser alterada nem excluída';
    FreeAndNil(AAtual);
    raise ERegraNegocio.Create(Msg);
  end;
  // T53 (UX 4.2): operacao pendente na fila bloqueia editar/excluir.
  // RF13-06: EInfra da verificacao vira ERegraNegocio amigavel (UI trata local).
  try
    Bloqueada := TemPendenciaFila(AId);
  except
    on EInfra do
    begin
      FreeAndNil(AAtual);
      raise ERegraNegocio.Create(MSG_FALHA_VERIFICAR_FILA);
    end;
  end;
  if Bloqueada then
  begin
    FreeAndNil(AAtual);
    raise ERegraNegocio.Create(MSG_BLOQUEIO_FILA);
  end;
end;

procedure TVendaService.AplicarPrecosETotal(const AVenda: TVenda; const AAtual: TVenda);
var
  Item, Antigo: TVendaItem;
  Produto: TProduto;
  Usados: TList<TVendaItem>;
  Total: Currency;
  Achou: Boolean;
begin
  Total := 0;
  Usados := TList<TVendaItem>.Create;
  try
    for Item in AVenda.Itens do
    begin
      Achou := False;
      if AAtual <> nil then
        for Antigo in AAtual.Itens do
          if (Antigo.ProdutoId = Item.ProdutoId) and (Usados.IndexOf(Antigo) < 0) then
          begin
            // Produto nao mudou: mantem o snapshot gravado.
            Item.PrecoUnitario := Antigo.PrecoUnitario;
            Usados.Add(Antigo);
            Achou := True;
            Break;
          end;
      if not Achou then
      begin
        Produto := FProdutoRepositorio.Obter(Item.ProdutoId);
        try
          Item.PrecoUnitario := Produto.PrecoUnitario;
        finally
          Produto.Free;
        end;
      end;
      Total := Total + Item.Quantidade * Item.PrecoUnitario;
    end;
  finally
    Usados.Free;
  end;
  AVenda.ValorTotal := Total;
end;

function TVendaService.Salvar(const AVenda: TVenda): Integer;
var
  Atual: TVenda;
begin
  Atual := nil;
  try
    if AVenda.Id > 0 then
      ExigirPendente(AVenda.Id, Atual);
    Validar(AVenda, Atual);
    AplicarPrecosETotal(AVenda, Atual);
    if Atual <> nil then
    begin
      // Edicao: status/quitacao/cancelamento vem sempre do banco (RF6-01).
      AVenda.Status := Atual.Status;
      AVenda.DataQuitacao := Atual.DataQuitacao;
      AVenda.MotivoCancelamento := Atual.MotivoCancelamento;
    end
    else
    begin
      // Inclusao: sempre Pendente, sem quitacao/cancelamento (RF6-04).
      AVenda.Status := svPendente;
      AVenda.DataQuitacao := 0;
      AVenda.MotivoCancelamento := '';
    end;
  finally
    Atual.Free;
  end;
  if AVenda.Id > 0 then
  begin
    FVendaRepositorio.Alterar(AVenda);
    Result := AVenda.Id;
  end
  else
  begin
    AVenda.Status := svPendente;
    if AVenda.DataVenda = 0 then
      AVenda.DataVenda := Now;
    Result := FVendaRepositorio.Incluir(AVenda);
    AVenda.Id := Result;
  end;
end;

function TVendaService.Obter(AId: Integer): TVenda;
begin
  Result := FVendaRepositorio.Obter(AId);
end;

function TVendaService.ListarDataSet(const AStatusFiltro: string;
  AClienteIdFiltro: Integer): TDataSet;
begin
  Result := FVendaRepositorio.ListarDataSet(AStatusFiltro, AClienteIdFiltro);
end;

procedure TVendaService.Excluir(AId: Integer);
var
  Atual: TVenda;
begin
  ExigirPendente(AId, Atual);
  Atual.Free;
  FVendaRepositorio.Excluir(AId);
end;

end.
