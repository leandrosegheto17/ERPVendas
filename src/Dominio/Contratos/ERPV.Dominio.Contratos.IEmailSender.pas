unit ERPV.Dominio.Contratos.IEmailSender;

{
  Interface de fronteira do Domínio (ADR-001/010) — só assinaturas; a
  implementação real (Indy TIdSMTP + OpenSSL) é EmailSender (T48), fora do
  Domínio. Esta unit não referencia Id*/Indy — só o "formato de resultado"
  (TResultadoEnvioEmail, ERPV.Dominio.Resultados), conforme TASK.md
  Seção 1 "Integração".
}

interface

uses
  ERPV.Dominio.Resultados;

type
  IEmailSender = interface
    ['{BF6A7B65-4D81-4A0F-E45F-6C7D8E9F0A1B}']

    /// <summary>Envia e-mail com anexo (PDF de confirmação de pedido,
    /// T47) para ADestinatario. Nunca lança exceção para falha esperada
    /// de SMTP (host indisponível, credencial errada etc.) — devolve
    /// TResultadoEnvioEmail.Falha nesses casos (T48/T49).</summary>
    function Enviar(const ADestinatario, AAssunto, ACorpo, ACaminhoAnexoPdf: string): TResultadoEnvioEmail;
  end;

implementation

end.
