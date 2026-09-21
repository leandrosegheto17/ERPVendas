# ADR-007 — E-mail via Indy TIdSMTP; configuração e segredos fora do repositório

- Status: Accepted (DEC-04/DEC-13 adotadas, com ajuste de segredos)
- Contexto: TLS em Indy depende de OpenSSL compatível (1.0.2u para Indy embarcado até Delphi 11; versões recentes têm mais opções); credenciais não podem ir para o Git.
- Alternativas: MAPI/Outlook (dependência do cliente); serviço externo HTTP (conta/custo).
- Decisão: `TIdSMTP` + `TIdSSLIOHandlerSocketOpenSSL` dentro de `TEmailSender` (`IEmailSender`); mensagem com anexo PDF. Config em `erpvendas.ini` (seção `[SMTP]`), `erpvendas.ini` no `.gitignore`, apenas `erpvendas.ini.example` versionado com valores fictícios. Senha SMTP: lida do INI ou, se definida, da variável de ambiente `ERPV_SMTP_PASSWORD` (prioridade). Dev/demo: Mailtrap/Ethereal (caixa de teste, sem entrega real). Teste de envio TLS real no D1/D2 (spike T01). DLLs OpenSSL empacotadas na pasta do exe, versão registrada no README. Nenhum segredo em `.pas/.dfm/.dpr`; nenhum segredo em log.
- Consequências: (+) simples; (-) casamento Indy x OpenSSL é risco (R-02): fallback = porta 25/587 sem TLS no Mailtrap para demo, documentado.
