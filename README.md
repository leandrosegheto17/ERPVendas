# ERP Vendas (Delphi)

Aplicação desktop Windows (Delphi, VCL + DevExpress) para cadastro de clientes e produtos, registro de vendas e **quitação integrada** a um sistema Financeiro (C#). Ao confirmar a quitação, o app notifica o Financeiro, grava o status local, gera o PDF do pedido (ReportBuilder) e o envia por e-mail ao cliente. Falhas de Financeiro/SMTP não perdem a operação: vão para uma fila de pendências com reenvio manual.

Este README cobre instalação e operação. Decisões de arquitetura estão em `.md/adr/` e `.md/SDD.md`; não são repetidas aqui.

## 1. Arquitetura resumida

```
UI (forms DevExpress finos)
  -> Negócio (ClienteService, ProdutoService, VendaService, QuitacaoService, FilaService)
       -> Dados: repositórios FireDAC -> Firebird 3.0 (ERPVENDAS.FDB)
       -> Integração: IFinanceiroGateway (THTTPClient) -> Financeiro C# / mock
                      IEmailSender (Indy SMTP)         -> servidor SMTP
                      IRelatorioPedido (ReportBuilder) -> PDF
Transversal: Config (INI), Log (arquivo), Erros, Validadores (CPF/CNPJ/e-mail)
```

Código em `src/{App,Core,Dominio,Negocio,Dados,Integracao,Relatorios,UI}`; projeto `ERPVendas.dpr`/`.dproj`. Formulários não contêm SQL nem HTTP. Detalhes: `.md/SDD.md`.

Fluxo de Confirmar quitação: POST ao Financeiro -> grava status local -> PDF -> e-mail. Se algo falhar (recusa, 500, timeout, SMTP), o item entra na fila (tela Pendências, "Reenviar").

## 2. Pré-requisitos

Plataforma-alvo: **Windows, 32 bits** (exe, `fbclient.dll` e OpenSSL na mesma arquitetura; ver `docs/ambiente-licencas.md` §6).

Para **compilar** (versões verificadas em `docs/ambiente-licencas.md`):

- Delphi 13 Community (Win32).
- DevExpress VCL 26.1.4 (skin `Office2019Colorful`).
- ReportBuilder Professional 23.04 (for Delphi 13).
- Firebird 3.0 (testado 3.0.14, Win32), com `isql` e `gbak`.
- Python 3.8+ (somente para o mock do Financeiro, opcional).

Para **executar** o app (máquina sem IDE), na mesma pasta do `ERPVendas.exe`:

- `fbclient.dll` 32 bits (do Firebird 3.0).
- `libeay32.dll` e `ssleay32.dll` do **OpenSSL 1.0.2, Win32**. O Indy 10.6.3 do Delphi 13 só carrega esses nomes; DLLs OpenSSL 1.1.x/3.x não funcionam. Só são necessárias para SMTP com TLS (ex.: porta 587); sem TLS (ex.: porta 2525) não são exigidas. Não são versionadas no repositório (binários de terceiros); o spike T02 usou o mirror `IndySockets/OpenSSL-Binaries` (`docs/ambiente-licencas.md` §11).
- Runtime packages do Delphi/DevExpress: a diretriz é build sem eles, mas ver limitação do trial DevExpress na seção 6.

O pacote `bin/` (exe + DLLs + `erpvendas.ini.example`) e o `db/ERPVENDAS.FBK` **são gerados na entrega** (tarefas T61/T62) e podem não existir no repositório. Sem eles, use os scripts SQL da seção 3 e compile o projeto na IDE.

## 3. Instalação passo a passo

### 3.1 Firebird 3.0

1. Instale o Firebird 3.0 (Windows, 32 bits, serviço SuperServer). Anote a senha do `SYSDBA` definida na instalação.
2. Crie a pasta de dados, ex.: `C:\ERPVendas\dados`.

### 3.2 Banco de dados

**Opção A: restaurar o backup (`gbak`)**, quando `ERPVENDAS.FBK` estiver no pacote:

```
gbak -c -user SYSDBA ERPVENDAS.FBK localhost:C:\ERPVendas\dados\ERPVENDAS.FDB
```

> **Aviso (senha):** não passe `-password <senha>` na linha de comando (fica no histórico do shell e na lista de processos). Defina antes `ISC_PASSWORD` (o `gbak`/`isql` do Firebird 3 também leem `ISC_USER`): no cmd `set ISC_PASSWORD=<senha>`; no PowerShell `$env:ISC_PASSWORD='<senha>'`; ao terminar, limpe (`set ISC_PASSWORD=` / `Remove-Item Env:ISC_PASSWORD`). Sem a variável, as ferramentas pedem a senha em prompt.

**Opção B: criar pelos scripts** (a partir da raiz do repositório):

1. Execute o `CREATE DATABASE` de `db/00_criar_banco.sql` (ajuste caminho e senha). O banco **precisa** ser `DEFAULT CHARACTER SET UTF8`, senão a busca sem acento falha. Use o prefixo `localhost:` e finalize a sessão `isql` com `QUIT;` antes de abrir o app (lock exclusivo).
2. `isql -user SYSDBA localhost:C:\ERPVendas\dados\ERPVENDAS.FDB -i db\01_schema.sql`
3. `isql -user SYSDBA localhost:C:\ERPVendas\dados\ERPVENDAS.FDB -i db\02_seed.sql` (dados fictícios: 2 clientes, 3 produtos).

Verificação: `SELECT RDB$CHARACTER_SET_NAME FROM RDB$DATABASE;` deve retornar `UTF8`.

### 3.3 Configuração (INI)

1. Copie `config/erpvendas.ini.example` para a pasta do executável com o nome **`erpvendas.ini`** (o app procura o INI na pasta do exe). Nunca versione o `.ini` real.
2. Ajuste as seções:

| Seção | Chaves | Observação |
|---|---|---|
| `[Banco]` | `Caminho`, `Usuario`, `Senha` | Caminho do `.FDB` |
| `[Financeiro]` | `BaseUrl`, `TimeoutSegundos`, `ApiKey` | `ApiKey` vazia = não envia `X-Api-Key`. Contrato: `docs/contrato-api-financeiro.md` |

> **Atenção (porta):** o `BaseUrl` do `config/erpvendas.ini.example` aponta para `http://localhost:5000`, mas o mock do Financeiro (seção 4) escuta por padrão na porta **8080** (`--port`). Ao usar o mock, ajuste `BaseUrl=http://127.0.0.1:8080` no seu `erpvendas.ini` (ou inicie o mock com `--port 5000`).
| `[SMTP]` | `Host`, `Porta`, `Usuario`, `Senha`, `UsaTLS` | Use caixa de teste (Mailtrap/Ethereal) |
| `[Relatorio]` | `PastaPdfTemp` | Deve existir e ter escrita |
| `[Log]` | `Pasta` | Deve existir e ter escrita |

Segredos preferencialmente por variável de ambiente (têm prioridade sobre o INI): `ERPV_BANCO_SENHA`, `ERPV_SMTP_PASSWORD`, `ERPV_FINANCEIRO_APIKEY`.

Crie as pastas de `PastaPdfTemp` e `Log` antes de abrir o app. Se o INI estiver ausente ou incompleto, o app exibe mensagem clara e encerra de forma controlada.

### 3.4 Executar

Com banco, INI e DLLs no lugar e o Financeiro (real ou mock) no ar, abra `ERPVendas.exe`. Roteiro de conferência: `docs/roteiro-testes-manuais.md` (12 cenários, incluindo INI ausente e instalação limpa).

## 4. Mock do Financeiro

Sem o Financeiro C#, use o mock (só Python stdlib, fora do pacote de entrega):

```
python tools/mock-financeiro/mock_financeiro.py --port 8080 --modo ok
```

Aponte `[Financeiro] BaseUrl=http://127.0.0.1:8080`. O modo muda em tempo de execução por `curl "http://127.0.0.1:8080/_modo?m=<ok|recusa|erro500|timeout|timeout-post|offline-simulado>"`. Estado em memória; `/_modo` sem autenticação (usar só em localhost). Detalhes em `tools/mock-financeiro/README.md`.

> **Aviso (rede):** o mock e a rota `/_modo` não têm autenticação; mantenha o padrão `--host 127.0.0.1` e não use `--host 0.0.0.0` fora do ambiente de desenvolvimento.

## 5. Nota LGPD (finalidade e retenção)

- **Dados tratados:** nome, CPF/CNPJ, endereço, telefone e e-mail de clientes, apenas o necessário ao cadastro, à venda e ao envio do pedido.
- **Finalidade:** registrar vendas, confirmar quitação e enviar o comprovante (PDF) ao e-mail do próprio cliente.
- **Compartilhamento:** na quitação o Financeiro recebe somente IDs, valores e itens (vendaId, clienteId, valorTotal, produtoId, quantidade, precoUnitario), sem dados pessoais; no cancelamento recebe o ID da venda e, se preenchido, o `motivo` (texto livre digitado pelo operador, opcional, até 255 caracteres). Oriente os operadores a **não digitar dado pessoal** no motivo, pois ele é enviado ao Financeiro (`docs/contrato-api-financeiro.md`). O PDF vai apenas ao e-mail do cliente.
- **Limite da máscara de logs:** `TLogger.MascararSensiveis` (`src/Core/ERPV.Core.Log.pas`) mascara CPF, CNPJ (formatados ou só dígitos), e-mail e pares `chave=valor`/`chave: valor` de senha/apikey/token/secret. **Não** cobre nome, telefone, endereço, documentos em formatos atípicos nem o texto devolvido pelo Financeiro e exibido na UI (mascaramento na UI pendente: SG13-01/RF13-04). Não registre esses dados no log.
- **Retenção:** cliente não é excluído fisicamente; é **inativado**, preservando o histórico de vendas (finalidade legítima). PDFs temporários ficam em `PastaPdfTemp` e são apagados após o envio (em falha, são regerados no reenvio). Não há expurgo automático do histórico de vendas no MVP; o prazo de guarda deve ser definido pelo responsável pelo tratamento.
- **Logs:** CPF/CNPJ e e-mail são mascarados; corpo de mensagens não é gravado.
- **Dados de demonstração:** fictícios (CPFs de teste válidos, e-mails de sandbox). Não use dados reais em demo.

## 6. Limitações do ambiente trial/demo (T01, T67)

- **ReportBuilder Professional (licença demo):** sem prazo de expiração, mas o **PDF exportado traz o bloco de aviso** "ReportBuilder Professional - Demo Copy ... Digital Metaphors Corporation" no rodapé (confirmado em 2026-09-22, `docs/ambiente-licencas.md` §3.2), além do aviso no Designer/Preview. Saída limitada a 5 páginas (o pedido cabe em 1). O aviso só some com licença comprada.
- **DevExpress VCL (trial):** expira ~30 dias após a instalação (2026-09-22; data exata a confirmar no License Manager). O trial exige compilar com **"Link with runtime packages"**, o que conflita com a diretriz de build sem runtime packages (T61). Não foi confirmado se isso some com licença comprada; enquanto for trial, as BPLs do DevExpress precisam acompanhar o exe.
- **Delphi Community:** licença registrada, 367 dias a partir de 2026-09-22.
- **OpenSSL:** apenas 1.0.2 Win32 (seção 2).

## 7. Mais documentação

- `docs/ambiente-licencas.md`: versões, licenças, spikes (SMTP, PDF, FireDAC).
- `docs/contrato-api-financeiro.md`: contrato HTTP com o Financeiro.
- `docs/roteiro-testes-manuais.md`: testes manuais.
- `.md/SDD.md`, `.md/adr/`: arquitetura e decisões.
