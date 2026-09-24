unit ERPV.Negocio.ProdutoService;

{
  T22 - Regras de negócio de Produto (RF-05). Camada Negócio: só depende de
  interfaces do Domínio e do Core (sem Vcl/FireDAC/Dados). Preço em Currency.
  T30: "excluir = inativar quando há venda" (RN-05) via IVendaRepository.
}

interface

uses
  System.SysUtils,
  Data.DB,
  ERPV.Core.Erros,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Produto,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IProdutoRepository;

type
  TProdutoService = class
  private
    FRepositorio: IProdutoRepository;
    FVendaRepositorio: IVendaRepository;
    procedure Validar(const AProduto: TProduto);
  public
    constructor Create(const ARepositorio: IProdutoRepository;
      const AVendaRepositorio: IVendaRepository);

    /// <summary>Normaliza (Trim), valida e inclui (Id = 0) ou altera (Id > 0).
    /// Devolve o Id. A entidade continua sendo do chamador.</summary>
    /// <exception cref="EValidacao">Campo obrigatório/inválido (Campo preenchido).</exception>
    function Salvar(const AProduto: TProduto): Integer;
    /// <summary>Devolve o produto (o chamador libera) ou nil.</summary>
    function Obter(AId: Integer): TProduto;
    function ListarDataSet(const AFiltroBusca: string; AIncluirInativos: Boolean): TDataSet;
    /// <summary>Com item de venda vinculado inativa (reInativado); sem venda
    /// exclui fisicamente (reExcluido). Inexistente: reExcluido.</summary>
    function Excluir(AId: Integer): TResultadoExclusao;
  end;

implementation

constructor TProdutoService.Create(const ARepositorio: IProdutoRepository;
  const AVendaRepositorio: IVendaRepository);
begin
  inherited Create;
  FRepositorio := ARepositorio;
  FVendaRepositorio := AVendaRepositorio;
end;

procedure TProdutoService.Validar(const AProduto: TProduto);
begin
  AProduto.Descricao := Trim(AProduto.Descricao);
  AProduto.Unidade := Trim(AProduto.Unidade);
  AProduto.Categoria := Trim(AProduto.Categoria);

  if AProduto.Descricao = '' then
    raise EValidacao.CreateCampo('Descricao', 'Informe a descrição');
  if AProduto.Unidade = '' then
    raise EValidacao.CreateCampo('Unidade', 'Informe a unidade');
  if AProduto.PrecoUnitario < 0 then
    raise EValidacao.CreateCampo('Preco', 'Preço inválido');
end;

function TProdutoService.Salvar(const AProduto: TProduto): Integer;
begin
  Validar(AProduto);
  if AProduto.Id > 0 then
  begin
    FRepositorio.Alterar(AProduto);
    Result := AProduto.Id;
  end
  else
  begin
    Result := FRepositorio.Incluir(AProduto);
    AProduto.Id := Result;
  end;
end;

function TProdutoService.Obter(AId: Integer): TProduto;
begin
  Result := FRepositorio.Obter(AId);
end;

function TProdutoService.ListarDataSet(const AFiltroBusca: string;
  AIncluirInativos: Boolean): TDataSet;
begin
  Result := FRepositorio.ListarDataSet(AFiltroBusca, AIncluirInativos);
end;

function TProdutoService.Excluir(AId: Integer): TResultadoExclusao;
var
  Item: TProduto;
begin
  if FVendaRepositorio.ExisteVendaPorProduto(AId) then
  begin
    Item := FRepositorio.Obter(AId);
    try
      if Item <> nil then
      begin
        Item.Ativo := False;
        FRepositorio.Alterar(Item);
      end;
    finally
      Item.Free;
    end;
    Exit(reInativado);
  end;
  FRepositorio.Excluir(AId);
  Result := reExcluido;
end;

end.
