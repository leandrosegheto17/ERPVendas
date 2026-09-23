unit ERPV.Dominio.Contratos.IClienteRepository;

{
  Interface de fronteira do Domínio (ADR-010) — só assinaturas, sem
  implementação (a implementação FireDAC é ClienteRepository, T17).
  Unit pura, sem Vcl/FireDAC/System.Net/Id*; a única referência fora do
  Domínio permitida é TDataSet (unit Data.DB), conforme ADR-010: métodos
  de escrita/edição usam entidade, métodos de listagem devolvem TDataSet
  somente leitura (acesso híbrido do ADR-003), com o form dono liberando
  o DataSet.
}

interface

uses
  Data.DB,
  ERPV.Dominio.Cliente;

type
  IClienteRepository = interface
    ['{6A1F2B10-9E3C-4B5A-9F0A-1D2E3F4A5B6C}']

    /// <summary>Grava um novo cliente e devolve o Id gerado.</summary>
    function Incluir(const ACliente: TCliente): Integer;

    /// <summary>Grava as alterações de um cliente já existente (ACliente.Id > 0).</summary>
    procedure Alterar(const ACliente: TCliente);

    /// <summary>Exclusão física — a regra "excluir = inativar quando há
    /// venda" (RN-05, T30) é do Service, não do repositório.</summary>
    procedure Excluir(AId: Integer);

    /// <summary>Devolve o cliente pelo Id, ou nil se não encontrado.</summary>
    function Obter(AId: Integer): TCliente;

    /// <summary>DataSet somente leitura para a grade de lista (T19), com
    /// busca textual e filtro de inativos.</summary>
    function ListarDataSet(const AFiltroBusca: string; AIncluirInativos: Boolean): TDataSet;

    /// <summary>Verifica se já existe cliente com o mesmo CPF/CNPJ
    /// (T18, validação de documento único). AIgnorarId permite excluir o
    /// próprio registro da checagem numa alteração (0 = não ignora nenhum).</summary>
    function ExistePorDocumento(const ACpfCnpj: string; AIgnorarId: Integer = 0): Boolean;
  end;

implementation

end.
