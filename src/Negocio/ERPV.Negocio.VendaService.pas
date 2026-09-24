unit ERPV.Negocio.VendaService;

{
  T27 - Regras de negocio de Venda (CRUD + validacoes, RF-07/08, RN-01/03).
  Camada Negocio: so depende de interfaces do Dominio e do Core.
  Fora do escopo: total/snapshot de preco (T28) e restricao por status (T29).
}

interface

uses
  System.SysUtils,
  Data.DB,
  ERPV.Core.Erros,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Cliente,
  ERPV.Dominio.Produto,
  ERPV.Dominio.Venda,
  ERPV.Dominio.VendaItem,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IClienteRepository,
  ERPV.Dominio.Contratos.IProdutoRepository;

type
  TVendaService = class
  private
    FVendaRepositorio: IVendaRepository;
    FClienteRepositorio: IClienteRepository;
    FProdutoRepositorio: IProdutoRepository;
    procedure Validar(const AVenda: TVenda);
  public
    constructor Create(const AVendaRepositorio: IVendaRepository;
      const AClienteRepositorio: IClienteRepository;
      const AProdutoRepositorio: IProdutoRepository);

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

constructor TVendaService.Create(const AVendaRepositorio: IVendaRepository;
  const AClienteRepositorio: IClienteRepository;
  const AProdutoRepositorio: IProdutoRepository);
begin
  inherited Create;
  FVendaRepositorio := AVendaRepositorio;
  FClienteRepositorio := AClienteRepositorio;
  FProdutoRepositorio := AProdutoRepositorio;
end;

procedure TVendaService.Validar(const AVenda: TVenda);
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
    if not Cliente.Ativo then
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
      if not Produto.Ativo then
        raise EValidacao.CreateCampo('Produto',
          Format('Produto "%s" inativo não pode ser vendido', [Produto.Descricao]));
    finally
      Produto.Free;
    end;
  end;
end;

function TVendaService.Salvar(const AVenda: TVenda): Integer;
begin
  Validar(AVenda);
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
begin
  FVendaRepositorio.Excluir(AId);
end;

end.
