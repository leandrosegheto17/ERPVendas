unit ERPV.Dominio.Contratos.IFilaRepository;

{
  Interface de fronteira do Domínio (ADR-010) — só assinaturas; a
  implementação FireDAC é FilaRepository (T37). Unit pura, sem
  Vcl/FireDAC/System.Net/Id*; TDataSet (Data.DB) é a única exceção,
  conforme ADR-010.

  Regra de negócio de Enfileirar (no máximo 1 item PENDENTE por
  venda+tipo, senão incrementa tentativas — RN-08, T37) é responsabilidade
  da implementação, não desta assinatura.
}

interface

uses
  Data.DB,
  ERPV.Dominio.Enums;

type
  IFilaRepository = interface
    ['{9D4E5F43-2B6F-4E8D-C23D-4A5B6C7D8E9F}']

    /// <summary>Enfileira uma tentativa para (AVendaId, ATipo): se já
    /// existe item PENDENTE para o mesmo par, incrementa TENTATIVAS e
    /// grava AErro em ULTIMO_ERRO em vez de duplicar a linha.</summary>
    procedure Enfileirar(AVendaId: Integer; ATipo: TTipoFila; const AErro: string = '');

    /// <summary>DataSet somente leitura para a grade de Pendências (T52).</summary>
    function Listar(ASomentePendentes: Boolean): TDataSet;

    /// <summary>Marca o item como CONCLUIDO e grava CONCLUIDO_EM.</summary>
    procedure MarcarConcluido(AId: Integer);

    /// <summary>Mantém PENDENTE, incrementa TENTATIVAS e grava
    /// ULTIMO_ERRO (truncado em 500 caracteres, T37).</summary>
    procedure RegistrarFalha(AId: Integer; const AErro: string);

    /// <summary>Total de itens PENDENTE — usado pelo contador
    /// "Pendências: N" (T53).</summary>
    function ContarPendencias: Integer;

    /// <summary>Verifica se existe item PENDENTE para (AVendaId, ATipo) —
    /// usado por T53 para bloquear Editar/Confirmar/Cancelar.</summary>
    function ExistePendenciaPorVenda(AVendaId: Integer; ATipo: TTipoFila): Boolean;
  end;

implementation

end.
