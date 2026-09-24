unit ERPV.Integracao.EmailSender;

(*
  EmailSender (T48, Lote 12; RF-21, ADR-007). Implementa IEmailSender sobre
  Indy TIdSMTP (+ TIdSSLIOHandlerSocketOpenSSL quando UsaTLS). Sem Vcl.

  Regras:
   - Host/Porta/Usuario/Senha/UsaTLS vem de TConfiguracaoSMTP (INI [SMTP];
     senha: ERPV_SMTP_PASSWORD tem prioridade, resolvido em ERPV.Core.Config).
     Esta unit nao le INI nem ambiente: recebe o record pronto por construtor.
   - Parametros validados no spike T02 (docs/ambiente-licencas.md 11.5):
     DLLs OpenSSL 1.0.2 Win32 (libeay32.dll + ssleay32.dll) na pasta do .exe;
     com TLS: UseTLS=utUseExplicitTLS, SSLOptions.Method=sslvTLSv1_2 (porta
     587); sem TLS: IOHandler=nil, UseTLS=utNoTLSSupport (ex.: porta 2525).
   - Falha esperada (host indisponivel, credencial errada, anexo ausente,
     DLL SSL ausente, timeout, destinatario invalido) => TResultadoEnvioEmail.
     Falha(mensagem fixa e segura), nunca excecao.
   - Log (opcional, ALogger pode ser nil): apenas etapa e CLASSE da excecao;
     nunca senha, corpo do e-mail nem a mensagem crua da excecao.
   - Remetente: parametro do construtor (INI [SMTP] nao tem campo From).
   - Sincrono; a chamada bloqueia ate o SMTP responder (timeouts abaixo).

  Composition root: ERPV.App.Root instancia TEmailSender.Create(
  Cfg.SMTP, Logger) e expoe como IEmailSender (property EmailSender).

  ROTEIRO MANUAL (Delphi Community nao compila via CLI; usar botao temporario
  ou projeto de teste; conta sandbox Mailtrap; PDF qualquer, ex.
  C:\temp\teste.pdf):
   1. Compilar (Shift+F9): 0 erros. DLLs OpenSSL 1.0.2 Win32 na pasta do exe.
   2. INI [SMTP] Host=sandbox.smtp.mailtrap.io, Porta=587, UsaTLS=1, Usuario e
      Senha reais. Enviar('cliente@exemplo.com','Teste T48','Corpo',
      'C:\temp\teste.pdf') => Sucesso=True; e-mail no inbox do Mailtrap com
      "Attachments (1)" abrivel.
   3. Porta=2525, UsaTLS=0 => Sucesso=True, anexo chega igual.
   4. Senha errada (INI ou ERPV_SMTP_PASSWORD errada) => Sucesso=False,
      MensagemErro preenchida, sem crash; conferir no log do dia que a senha
      NAO aparece em nenhuma linha.
   5. Host invalido/porta fechada => Falha sem crash (respeita timeout ~15 s).
   6. Caminho de anexo inexistente => Falha (sem tentar conectar).
   7. UsaTLS=1 sem as DLLs OpenSSL na pasta do exe => Falha sem crash.
   8. ERPV_SMTP_PASSWORD definida com senha correta e INI com senha errada =>
      Sucesso=True (prioridade da variavel de ambiente).
*)

interface

uses
  System.SysUtils,
  System.Classes,
  IdSMTP,
  IdSMTPBase,
  IdMessage,
  IdText,
  IdAttachmentFile,
  IdSSLOpenSSL,
  IdExplicitTLSClientServerBase,
  IdException,
  ERPV.Core.Config,
  ERPV.Core.Log,
  ERPV.Dominio.Resultados,
  ERPV.Dominio.Contratos.IEmailSender;

type
  TEmailSender = class(TInterfacedObject, IEmailSender)
  private
    FConfig: TConfiguracaoSMTP;
    FLogger: TLogger;
    FRemetente: string;
    procedure LogInfo(const AMsg: string);
    procedure LogErro(const AMsg: string; AExcecao: Exception);
  public
    /// <param name="AConfig">Bloco [SMTP] ja resolvido (senha inclusa).</param>
    /// <param name="ALogger">Opcional (pode ser nil); nao e dono.</param>
    /// <param name="ARemetente">Endereco do From; vazio usa padrao.</param>
    constructor Create(const AConfig: TConfiguracaoSMTP; ALogger: TLogger;
      const ARemetente: string = '');
    function Enviar(const ADestinatario, AAssunto, ACorpo,
      ACaminhoAnexoPdf: string): TResultadoEnvioEmail;
  end;

implementation

const
  REMETENTE_PADRAO = 'nao-responder@erpvendas.local';
  TIMEOUT_CONEXAO_MS = 15000;
  TIMEOUT_LEITURA_MS = 30000;

  MSG_ANEXO_AUSENTE = 'Nao foi possivel anexar o PDF do pedido ao e-mail.';
  MSG_CREDENCIAL = 'O servidor de e-mail recusou o usuario ou a senha configurados.';
  MSG_REJEITADO = 'O servidor de e-mail recusou o envio da mensagem.';
  MSG_SSL = 'Nao foi possivel estabelecer conexao segura (TLS) com o servidor de e-mail.';
  MSG_CONEXAO = 'Nao foi possivel conectar ao servidor de e-mail.';
  MSG_GENERICA = 'Nao foi possivel enviar o e-mail.';
  MSG_DESTINATARIO = 'Destinatario do e-mail nao informado.';

{ TEmailSender }

constructor TEmailSender.Create(const AConfig: TConfiguracaoSMTP;
  ALogger: TLogger; const ARemetente: string);
begin
  inherited Create;
  FConfig := AConfig;
  FLogger := ALogger;
  if Trim(ARemetente) <> '' then
    FRemetente := Trim(ARemetente)
  else
    FRemetente := REMETENTE_PADRAO;
end;

procedure TEmailSender.LogInfo(const AMsg: string);
begin
  if Assigned(FLogger) then
    FLogger.Info(AMsg);
end;

procedure TEmailSender.LogErro(const AMsg: string; AExcecao: Exception);
begin
  // So a CLASSE da excecao entra no log: a mensagem crua de Indy/SMTP pode
  // ecoar dados da sessao. Nunca senha nem corpo do e-mail.
  if Assigned(FLogger) then
    FLogger.Erro(AMsg + ' [' + AExcecao.ClassName + ']');
end;

function TEmailSender.Enviar(const ADestinatario, AAssunto, ACorpo,
  ACaminhoAnexoPdf: string): TResultadoEnvioEmail;
var
  LSmtp: TIdSMTP;
  LSsl: TIdSSLIOHandlerSocketOpenSSL;
  LMsg: TIdMessage;
  LTexto: TIdText;
  LAnexo: TIdAttachmentFile;
begin
  if Trim(ADestinatario) = '' then
    Exit(TResultadoEnvioEmail.Falha(MSG_DESTINATARIO));
  if (ACaminhoAnexoPdf <> '') and not FileExists(ACaminhoAnexoPdf) then
  begin
    LogInfo('Envio de e-mail abortado: anexo PDF inexistente.');
    Exit(TResultadoEnvioEmail.Falha(MSG_ANEXO_AUSENTE));
  end;

  LSmtp := nil;
  LSsl := nil;
  LMsg := nil;
  try
    try
      LMsg := TIdMessage.Create(nil);
      LMsg.From.Address := FRemetente;
      LMsg.Recipients.EmailAddresses := Trim(ADestinatario);
      LMsg.Subject := AAssunto;
      LMsg.CharSet := 'utf-8';
      LMsg.ContentType := 'multipart/mixed';

      LTexto := TIdText.Create(LMsg.MessageParts, nil);
      LTexto.Body.Text := ACorpo;
      LTexto.ContentType := 'text/plain';
      LTexto.CharSet := 'utf-8';

      if ACaminhoAnexoPdf <> '' then
      begin
        LAnexo := TIdAttachmentFile.Create(LMsg.MessageParts, ACaminhoAnexoPdf);
        LAnexo.ContentType := 'application/pdf';
      end;

      LSmtp := TIdSMTP.Create(nil);
      LSmtp.Host := FConfig.Host;
      LSmtp.Port := FConfig.Porta;
      LSmtp.Username := FConfig.Usuario;
      LSmtp.Password := FConfig.Senha;
      LSmtp.ConnectTimeout := TIMEOUT_CONEXAO_MS;
      LSmtp.ReadTimeout := TIMEOUT_LEITURA_MS;

      if FConfig.UsaTLS then
      begin
        LSsl := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
        LSsl.SSLOptions.Method := sslvTLSv1_2; // validado no spike T02
        LSsl.SSLOptions.Mode := sslmClient;
        LSmtp.IOHandler := LSsl;
        LSmtp.UseTLS := utUseExplicitTLS;
      end
      else
      begin
        LSmtp.IOHandler := nil;
        LSmtp.UseTLS := utNoTLSSupport;
      end;

      LSmtp.Connect;
      try
        LSmtp.Send(LMsg);
      finally
        if LSmtp.Connected then
          try
            LSmtp.Disconnect;
          except
            // falha ao fechar a sessao nao muda o resultado do envio
          end;
      end;

      LogInfo('E-mail enviado ao servidor SMTP.');
      Result := TResultadoEnvioEmail.Ok;
    except
      on E: EIdSMTPReplyError do
      begin
        // 535/534/530 = autenticacao; demais = recusa do servidor.
        LogErro('Falha SMTP (resposta do servidor, codigo ' +
          IntToStr(E.ErrorCode) + ')', E);
        if (E.ErrorCode = 535) or (E.ErrorCode = 534) or (E.ErrorCode = 530) then
          Result := TResultadoEnvioEmail.Falha(MSG_CREDENCIAL)
        else
          Result := TResultadoEnvioEmail.Falha(MSG_REJEITADO);
      end;
      on E: EIdOSSLException do
      begin
        LogErro('Falha SMTP (TLS/OpenSSL)', E);
        Result := TResultadoEnvioEmail.Falha(MSG_SSL);
      end;
      on E: EIdException do
      begin
        LogErro('Falha SMTP (Indy/rede)', E);
        Result := TResultadoEnvioEmail.Falha(MSG_CONEXAO);
      end;
      on E: Exception do
      begin
        LogErro('Falha inesperada no envio de e-mail', E);
        Result := TResultadoEnvioEmail.Falha(MSG_GENERICA);
      end;
    end;
  finally
    LSmtp.Free;
    LSsl.Free;
    LMsg.Free;
  end;
end;

end.
