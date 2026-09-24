unit ERPV.Dominio.Contratos.IRelatorioPedido;

(*
  Interface de fronteira do Domínio (ADR-001/010) — só assinaturas; a
  implementação real (ReportBuilder) é RelatorioPedido (T47), fora do
  Domínio. Esta unit não referencia unit alguma do ReportBuilder/Vcl.
*)

interface

uses
  ERPV.Dominio.Venda;

type
  IRelatorioPedido = interface
    ['{C07B8C76-5E92-4B10-F560-7D8E9F0A1B2C}']

    /// <summary>Gera o PDF "Confirmação de Pedido" (T46) na pasta temp
    /// configurada (ADR-007) e devolve o caminho completo do arquivo
    /// gerado.</summary>
    function GerarPdf(const AVenda: TVenda): string;

    /// <summary>Remove o arquivo gerado por GerarPdf (limpeza após envio
    /// de e-mail bem-sucedido, T49; regenerado a partir do banco em caso
    /// de reenvio, T51 — PDF não é persistido, SDD.md Seção 4).</summary>
    procedure Limpar(const ACaminhoArquivo: string);
  end;

implementation

end.
