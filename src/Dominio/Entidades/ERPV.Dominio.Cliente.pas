unit ERPV.Dominio.Cliente;

(*
  Entidade de Domínio TCliente (T08, Lote 2). Campos batendo com
  db/01_schema.sql (tabela CLIENTES, criada em T03). Unit pura, sem
  Vcl/FireDAC/System.Net/Id* (ADR-001/010).
*)

interface

uses
  System.SysUtils;

type
  /// <summary>'F' = pessoa física, 'J' = pessoa jurídica (CK_CLIENTES_TIPO).</summary>
  TTipoPessoa = (tpFisica, tpJuridica);

  TCliente = class
  private
    FId: Integer;
    FNome: string;
    FTipoPessoa: TTipoPessoa;
    FCpfCnpj: string;
    FEndereco: string;
    FTelefone: string;
    FEmail: string;
    FAtivo: Boolean;
  public
    constructor Create;

    property Id: Integer read FId write FId;
    property Nome: string read FNome write FNome;
    property TipoPessoa: TTipoPessoa read FTipoPessoa write FTipoPessoa;
    /// <summary>Só dígitos (TASK.md Seção 1 "Dados"): normalização é
    /// responsabilidade do Service (T18), não desta entidade.</summary>
    property CpfCnpj: string read FCpfCnpj write FCpfCnpj;
    property Endereco: string read FEndereco write FEndereco;
    property Telefone: string read FTelefone write FTelefone;
    property Email: string read FEmail write FEmail;
    property Ativo: Boolean read FAtivo write FAtivo;
  end;

function TipoPessoaToChar(ATipo: TTipoPessoa): Char;
function CharToTipoPessoa(AChar: Char): TTipoPessoa;

implementation

constructor TCliente.Create;
begin
  inherited Create;
  FAtivo := True;
  FTipoPessoa := tpFisica;
end;

function TipoPessoaToChar(ATipo: TTipoPessoa): Char;
begin
  if ATipo = tpFisica then
    Result := 'F'
  else
    Result := 'J';
end;

function CharToTipoPessoa(AChar: Char): TTipoPessoa;
begin
  case AChar of
    'F': Result := tpFisica;
    'J': Result := tpJuridica;
  else
    raise EArgumentException.CreateFmt('Tipo de pessoa desconhecido: "%s"', [AChar]);
  end;
end;

end.
