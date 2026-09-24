unit ERPV.Negocio.ClienteService;

(*
  T18 - Regras de negocio de Cliente (RF-01/02/03). Camada Negocio: so
  depende de interfaces do Dominio e do Core (sem Vcl/FireDAC/Dados).
  T30: "excluir = inativar quando ha venda" (RN-05) via IVendaRepository.
*)

interface

uses
  System.SysUtils,
  Data.DB,
  ERPV.Core.Erros,
  ERPV.Core.Validadores,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Cliente,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IClienteRepository;

type
  TClienteService = class
  private
    FRepositorio: IClienteRepository;
    FVendaRepositorio: IVendaRepository;
    procedure Validar(const ACliente: TCliente);
  public
    constructor Create(const ARepositorio: IClienteRepository;
      const AVendaRepositorio: IVendaRepository);

    /// <summary>Normaliza (CPF/CNPJ so digitos), valida e inclui (Id = 0) ou
    /// altera (Id > 0). Devolve o Id. A entidade continua sendo do chamador.</summary>
    /// <exception cref="EValidacao">Campo obrigatorio/invalido/duplicado (Campo preenchido).</exception>
    function Salvar(const ACliente: TCliente): Integer;
    /// <summary>Devolve o cliente (o chamador libera) ou nil.</summary>
    function Obter(AId: Integer): TCliente;
    function ListarDataSet(const AFiltroBusca: string; AIncluirInativos: Boolean): TDataSet;
    /// <summary>Com venda vinculada inativa (reInativado); sem venda exclui
    /// fisicamente (reExcluido). Inexistente: reExcluido.</summary>
    function Excluir(AId: Integer): TResultadoExclusao;
  end;

implementation

constructor TClienteService.Create(const ARepositorio: IClienteRepository;
  const AVendaRepositorio: IVendaRepository);
begin
  inherited Create;
  FRepositorio := ARepositorio;
  FVendaRepositorio := AVendaRepositorio;
end;

procedure TClienteService.Validar(const ACliente: TCliente);
begin
  ACliente.Nome := Trim(ACliente.Nome);
  ACliente.Email := Trim(ACliente.Email);
  ACliente.CpfCnpj := NormalizarDocumento(ACliente.CpfCnpj);

  if ACliente.Nome = '' then
    raise EValidacao.CreateCampo('Nome', 'Informe o nome');

  if ACliente.CpfCnpj = '' then
    raise EValidacao.CreateCampo('CpfCnpj', 'Informe o CPF/CNPJ');
  if (ACliente.TipoPessoa = tpFisica) and not CpfValido(ACliente.CpfCnpj) then
    raise EValidacao.CreateCampo('CpfCnpj', 'CPF inválido');
  if (ACliente.TipoPessoa = tpJuridica) and not CnpjValido(ACliente.CpfCnpj) then
    raise EValidacao.CreateCampo('CpfCnpj', 'CNPJ inválido');

  if ACliente.Email = '' then
    raise EValidacao.CreateCampo('Email', 'Informe o e-mail');
  if not EmailValido(ACliente.Email) then
    raise EValidacao.CreateCampo('Email', 'E-mail inválido');

  if FRepositorio.ExistePorDocumento(ACliente.CpfCnpj, ACliente.Id) then
    raise EValidacao.CreateCampo('CpfCnpj', 'Documento já cadastrado');
end;

function TClienteService.Salvar(const ACliente: TCliente): Integer;
begin
  Validar(ACliente);
  if ACliente.Id > 0 then
  begin
    FRepositorio.Alterar(ACliente);
    Result := ACliente.Id;
  end
  else
  begin
    Result := FRepositorio.Incluir(ACliente);
    ACliente.Id := Result;
  end;
end;

function TClienteService.Obter(AId: Integer): TCliente;
begin
  Result := FRepositorio.Obter(AId);
end;

function TClienteService.ListarDataSet(const AFiltroBusca: string;
  AIncluirInativos: Boolean): TDataSet;
begin
  Result := FRepositorio.ListarDataSet(AFiltroBusca, AIncluirInativos);
end;

function TClienteService.Excluir(AId: Integer): TResultadoExclusao;
var
  Item: TCliente;
begin
  if FVendaRepositorio.ExisteVendaPorCliente(AId) then
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
