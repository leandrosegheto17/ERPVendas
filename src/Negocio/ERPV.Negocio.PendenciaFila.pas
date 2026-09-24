unit ERPV.Negocio.PendenciaFila;

(*
  T53 - Regra unica de bloqueio por fila pendente (UX-SPEC 4.2, ADR-005, INT-03).
  Venda Pendente com item QUITACAO ou CANCELAMENTO PENDENTE na fila tem
  Editar/Excluir/Confirmar/Cancelar bloqueados: ha operacao em curso no
  Financeiro (usar Pendencias). EMAIL nao bloqueia (a venda ja esta Quitada).
  Camada Negocio: so depende de interface do Dominio. AFila nil = sem fila
  configurada (nunca bloqueia). Sem log e sem dado pessoal.
*)

interface

uses
  ERPV.Dominio.Contratos.IFilaRepository;

const
  MSG_BLOQUEIO_FILA = 'Há uma operação pendente de envio ao Financeiro para esta ' +
    'venda. Resolva em Pendências antes de continuar.';

/// <summary>True se ha QUITACAO ou CANCELAMENTO PENDENTE para a venda.</summary>
function VendaBloqueadaPorFila(const AFila: IFilaRepository; AVendaId: Integer): Boolean;

implementation

uses
  ERPV.Dominio.Enums;

function VendaBloqueadaPorFila(const AFila: IFilaRepository; AVendaId: Integer): Boolean;
begin
  Result := (AFila <> nil) and (AVendaId > 0) and
    (AFila.ExistePendenciaPorVenda(AVendaId, tfQuitacao) or
     AFila.ExistePendenciaPorVenda(AVendaId, tfCancelamento));
end;

end.
