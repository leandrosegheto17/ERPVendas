# Varredura de segredos e licencas (T63) - 2026-09-24

## 1. Metodo (sem segredos)

- Arvore versionada: `git ls-files` + `git grep -nIEi` para senha/pwd/password/token/api key/secret/serial/license, chaves privadas (`BEGIN ... PRIVATE`, `AKIA`, `sk_live`, `ghp_`, `xox`), hosts (`smtp.`, `mailtrap`, URLs), IPv4, e-mails e UUIDs.
- Historico: `git rev-list --all` (227 commits) e `git log --all -p` filtrando linhas adicionadas com os mesmos padroes; `git log --all --name-only` procurando arquivos `*.ini/*.log/*.pdf/*.fdb/*.fbk/*.env/*.pem/*.key`, `bin/`, `Win32/`.
- Pacote: `bin/` (27 arquivos) listado; `strings` em `ERPVendas.exe` por password/senha/apikey/secret/token/URLs/mailtrap/sysdba/caminhos de usuario; `cmp` do `erpvendas.ini.example` do pacote contra o versionado.

## 2. Achados

| Local / padrao | Classificacao | Acao |
|---|---|---|
| `config/erpvendas.ini.example`: `senha_ficticia_dev`, `senha_ficticia_smtp`, `usuario_ficticio_mailtrap`, `sandbox.smtp.mailtrap.io`, `ApiKey=` vazio | Ficticio/aceitavel (host publico de sandbox, sem credencial) | Nenhuma |
| `src/Core/ERPV.Core.Erros.pas:107` (`host=10.0.0.5` em comentario) | Ficticio (IP privado em exemplo de mensagem) | Nenhuma |
| E-mails (`a@b.com`, `*@example.com`, `nao-responder@erpvendas.local`, `teste@erpvendas.local`) | Ficticio | Nenhuma |
| Codigo Delphi (`Password :=`, `ERPV_*_SENHA/PASSWORD/APIKEY`) | Leitura por env/INI, sem literal | Nenhuma |
| UUIDs em `src/Dominio/Contratos/*` e `*.dproj` | GUIDs de interface/projeto Delphi, nao segredo | Nenhuma |
| UUIDs em `.claude/skills/cloudflare-deploy/.../tunnel/README.md` e `create-technical-design-doc/SKILL.md` | Exemplos de documentacao de terceiros (id de tunel de exemplo, `550e8400-...`) | Nenhuma |
| `.claude/skills/**` (`API_TOKEN=...`, `your-token-here`, `sk_live_abc123` como contra-exemplo) | Placeholders de docs de skills | Nenhuma |
| Historico: mesmos padroes; UUIDs unicos sao os acima (GUIDs, exemplos) | Ficticio/aceitavel | Nenhuma |
| Historico: nenhum arquivo `*.ini` (exceto `.example`), `*.log`, `*.pdf`, `*.fdb`, `*.fbk`, `.env`, `*.pem`, `*.key`, `bin/`, `Win32/` | Limpo | Nenhuma |
| Chave de API real do Financeiro (UUID) e nome de arquivo com ela | Nao encontrada na arvore nem no historico (nenhum UUID fora dos acima) | Nenhuma |
| `ERPVendas.exe` (strings) | Apenas nomes de campos (`Password`, `FPassword`), `http://localhost` (redirect OAuth de componentes) e URLs de namespaces XMP/XML; sem senha, chave, host real, caminho de usuario, `sysdba`/`.fdb` | Nenhuma |
| `bin/` | Sem `erpvendas.ini` real, log, PDF ou `.fdb`; `erpvendas.ini.example` identico ao versionado | Nenhuma |
| `.gitignore` | Faltavam `*.fdb`, `*.fbk`, `*.bpl` | Adicionados nesta tarefa |

Achados reais: **nenhum**.

## 3. Veredito por item do criterio

- Zero ocorrencias reais (arvore + historico): **sim**.
- `.gitignore` cobre INI (`erpvendas.ini`, `config/*.ini`, exceto `.example`), `*.log`/`logs/`, `*.pdf`, `.env`/`.env.*`, `bin/`, `Win32/`/`Win64/`, `__history/`, `*.local`, `*.res`, `*.exe`, `*.dcu`, `*.slip/*.lic/*.key`: **sim**, apos adicionar `*.fdb`, `*.fbk`, `*.bpl`.
- Pacote `bin/` sem segredos/INI real/logs/PDFs/banco: **sim**.
- Resultado anotado: este arquivo.

## 4. Licencas dos componentes (conforme `docs/ambiente-licencas.md` e README)

| Componente | Status documentado | Risco / lacuna |
|---|---|---|
| DevExpress VCL 26.1.4 trial | Trial 30 dias desde 2026-09-22, vence ~2026-10-22 (data exata a confirmar no License Manager). Exige runtime packages; `.bpl` dx*/cx* estao em `bin/` | Os `.bpl` do trial **nao sao redistribuiveis** e o binario deixa de funcionar apos a expiracao. O README (secao 6) passou a avisar (T63, 2026-09-24) que o binario expira e que os `.bpl` nao sao redistribuiveis: lacuna corrigida. |
| ReportBuilder Professional 23.04 "Demo Software" | Sem prazo; limite 5 paginas; PDF com aviso "Demo Copy" (README secao 6, ambiente-licencas s3) | Compilado no exe (units `pp*`); distribuicao do exe com demo depende dos termos da licenca demo, nao documentados alem do resumo. Aviso no PDF permanece. |
| Delphi Community | Registrada, 367 dias desde 2026-09-22 | Termos da Community (limite de receita/uso comercial) nao detalhados no repo. |
| Firebird `fbclient.dll` | Presente em `bin/` | O repositorio **nao documenta** a licenca (IDPL/IPL) nem a versao/origem da DLL. Lacuna. |
| Indy 10.6.3.11 | Embutido no Delphi 13; OpenSSL 1.0.2 Win32 citado (README/ambiente-licencas s11) | Licenca do Indy e do OpenSSL nao registradas; DLLs OpenSSL nao estao em `bin/`. |
| Icones | Gerados por `scripts/gerar-icones.js`, uso livre no projeto; MIT/ISC (Lucide/Feather) so mencionado como alternativa (s13) | Sem pendencia. |
| `.bpl` da RTL/VCL Delphi (`rtl370`, `vcl370`, ...) | Em `bin/` | Redistribuicao sujeita aos termos da Community; nao documentado. |

Pendente (nao bloqueia a T63): o aviso de expiracao/nao redistribuicao ja esta no README; falta registrar em `ambiente-licencas.md` a licenca/origem do `fbclient.dll`.
