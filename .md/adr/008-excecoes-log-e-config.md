# ADR-008 — Tratamento central de exceções, log em arquivo e config INI

- Status: Accepted (propostas VISAO adotadas)
- Decisão:
  - Hierarquia `EErpVendas` > `EValidacao` (campo + mensagem), `ERegraNegocio`, `EIntegracao`, `EInfra`. Services lançam; forms capturam `EValidacao/ERegraNegocio` para exibir inline/`MessageDlg`; `Application.OnException` trata o resto: mensagem amigável ("Ocorreu um erro inesperado. Detalhes em log.") + gravação da stack/mensagem no log. Nunca exibir mensagem crua do Firebird/HTTP ao usuário.
  - Log em arquivo texto (`logs/erpvendas-AAAAMMDD.log`, UTF-8, append, `TCriticalSection` desnecessária pois é thread único), níveis INFO/WARN/ERRO. Não grava senha, corpo completo de e-mail nem CPF/CNPJ completos (mascarado `***.456.789-**`). Falha de gravar log nunca lança exceção.
  - Config `erpvendas.ini`: `[Banco]` (caminho/host, usuário, senha), `[Financeiro]` (BaseUrl, TimeoutMs, ApiKey opcional), `[SMTP]`, `[Relatorio]` (pasta de saída PDF). Ausência do INI => mensagem clara de configuração e encerra.
- Consequências: (+) uma via única de erro; (-) log em arquivo sem rotação (aceito; arquivo por dia).
