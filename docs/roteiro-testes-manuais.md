# Roteiro de Testes Manuais (enxuto)

Origem: SDD §7 (estratégia de teste manual), R-09. Mensagens abaixo conforme o código em `src/`.

## Pré-requisitos e dados de teste

- Banco restaurado com `db/01_schema.sql` + `db/02_seed.sql` (ou `ERPVENDAS.FBK`); `erpvendas.ini` copiado de `config/erpvendas.ini.example` e ajustado (Banco, Financeiro, SMTP Mailtrap, PastaPdfTemp, Log).
- Mock do Financeiro: `python tools/mock-financeiro/mock_financeiro.py --port 8080 --modo ok`; INI `[Financeiro] BaseUrl=http://127.0.0.1:8080`, `TimeoutSegundos=10`. Trocar modo: `curl "http://127.0.0.1:8080/_modo?m=<ok|recusa|erro500|timeout|timeout-post|offline-simulado>"`.
- Seed: Cliente 1 "Cliente Exemplo 1" (PF, CPF 52998224725, e-mail cliente.exemplo1@example.com); Cliente 2 "Empresa Exemplo 2 Ltda" (PJ, CNPJ 11222333000181); Produtos A (UN, 19,90), B (CX, 145,50), C (KG, 8,75).
- Notação: Dado = entrada; Passos numerados; Esperado = resultado verificável. Anexar prints/PDF como evidência.

## C1. CRUD e validações de Cliente
Dado: CPF inválido `11111111111`; CNPJ inválido `11222333000180`; e-mail `abc`; CPF duplicado `52998224725`.
1. Clientes > Novo. Nome "Teste", PF, CPF `11111111111`, e-mail válido. Salvar.
2. Trocar para PJ com CNPJ `11222333000180`. Salvar.
3. Corrigir o documento, e-mail `abc`. Salvar.
4. E-mail válido, documento `52998224725`. Salvar.
5. Deixar Nome, CPF/CNPJ ou e-mail vazios. Salvar.
6. Cadastro válido (CPF `39053344705`, e-mail `t@example.com`). Depois editar e inativar.

Esperado: (1) "CPF invalido"; (2) "CNPJ invalido"; (3) "E-mail invalido"; (4) "Documento ja cadastrado"; (5) "Informe o nome" / "Informe o CPF/CNPJ" / "Informe o e-mail" no campo, sem gravar; (6) grava e aparece na grade; após inativar exibe "Inativo" e não aparece habilitado no lookup de venda. Nenhuma mensagem expõe SQL/caminho.

## C2. CRUD e validações de Produto
Dado: descrição vazia; unidade vazia; preço vazio ou negativo (o preço 0 é aceito).
1. Produtos > Novo; salvar sem descrição; sem unidade; com preço vazio; com preço negativo (ex.: -1,00); com preço 0,00.
2. Cadastrar "Produto Teste", UN, 10,00; editar o preço; inativar.

Esperado: "Informe a descrição", "Informe a unidade", "Preço inválido" (preço vazio ou negativo); preço 0,00 é aceito e grava; cadastro válido aparece na lista; inativo exibe "Inativo" e não é selecionável em venda.

## C3. Venda: validações e snapshot de preço
Dado: Cliente 1; Produtos A (19,90) e B (145,50).
1. Vendas > Nova venda; salvar sem cliente. Selecionar cliente e salvar/confirmar sem itens.
2. Adicionar item Produto A com quantidade 0.
3. Adicionar A qtd 2 e B qtd 1. Salvar.
4. Tentar usar cliente/produto inativo (de C1/C2).
5. Alterar o preço de A no cadastro para 25,00; reabrir a venda.

Esperado: (1) "Informe o cliente" / "A venda deve ter ao menos um item"; (2) "A quantidade deve ser maior que zero"; (3) total = 2×19,90 + 145,50 = R$ 185,30 (calculado, não digitável), status Pendente; (4) inativos não selecionáveis (se forçado: "Cliente inativo não pode receber venda" / `Produto "..." inativo não pode ser vendido`); (5) item de A continua a 19,90 e total 185,30.

## C4. Regras de status (só Pendente edita)
Dado: uma venda Pendente, uma Quitada (C5), uma Cancelada (C9).
1. Abrir a Pendente: editar/excluir permitido.
2. Abrir a Quitada e a Cancelada; tentar alterar/excluir.

Esperado: banners "Venda Quitada: somente leitura" / "Venda Cancelada: somente leitura", campos desabilitados; operações recusadas com "Venda já quitada não pode ser alterada nem excluída" / "Venda cancelada não pode ser alterada nem excluída".

## C5. Quitação OK + e-mail + PDF
Dado: mock `ok`; SMTP Mailtrap válido; venda Pendente de C3 (R$ 185,30) do Cliente 1.
1. Abrir a venda > Confirmar venda.
2. Ler o diálogo e confirmar.
3. Conferir Mailtrap e `PastaPdfTemp`.

Esperado: diálogo "Confirmar a venda N (R$ 185,30)? Esta ação envia a quitação ao Financeiro."; status Quitada com data de quitação preenchida; mock recebeu 1 POST `/api/vendas/quitacao` (`GET /api/vendas/N/status` = Quitada); e-mail "Confirmação de Pedido N" no Mailtrap com PDF anexo (corpo "Segue em anexo a confirmação do pedido N."); PDF temporário removido após o envio; Pendências vazia; log sem senha nem CPF/e-mail completos.

## C6. Recusa (4xx), 500 e timeout -> fila -> Reenviar
Dado: mock no ar em `http://127.0.0.1:8080`; Cliente 1 e Produto A cadastrados; uma nova venda Pendente (cliente + item) criada para cada sub-caso (A a D); o sub-caso E reaproveita uma venda que foi para a fila em B, C ou D.

**A) Recusa (4xx)**
1. Vendas > Nova venda; selecionar Cliente 1, adicionar Produto A qtd 1 e salvar (status Pendente).
2. Definir o modo: `curl "http://127.0.0.1:8080/_modo?m=recusa"`.
3. Abrir a venda > Confirmar venda e confirmar no diálogo.

Esperado: "Quitação recusada pelo Financeiro: Operacao recusada pelo Financeiro (modo simulado: recusa). A venda continua Pendente." (se o corpo do Financeiro não trouxer mensagem, o texto é "Quitacao recusada pelo Financeiro (codigo HTTP 422)", conforme o fallback do cliente); venda continua Pendente.

**B) Erro 500**
1. Criar uma nova venda Pendente (Cliente 1, Produto A qtd 1).
2. Definir o modo: `curl "http://127.0.0.1:8080/_modo?m=erro500"`.
3. Abrir a venda > Confirmar venda e confirmar no diálogo.
4. Reabrir a venda e tentar confirmar ou cancelar de novo.

Esperado: "Financeiro indisponível. A venda N continua Pendente e foi colocada na fila. Tente novamente em Pendências."; barra de status "Pendências: 1"; banner na venda "Operação pendente de envio ao Financeiro: somente leitura. Use Pendências."; nova quitação/cancelamento bloqueado até resolver ("Há uma operação pendente de envio ao Financeiro para esta venda. Resolva em Pendências antes de continuar.").

**C) Timeout**
1. Criar uma nova venda Pendente (Cliente 1, Produto A qtd 1).
2. Definir o modo: `curl "http://127.0.0.1:8080/_modo?m=timeout"`.
3. Abrir a venda > Confirmar venda e confirmar no diálogo; aguardar (o cliente espera ~10 s por chamada).

Esperado: cursor de espera e botões desabilitados; retorno em ~10 s com a mesma mensagem de indisponível; item na fila.

**D) Offline simulado**
1. Criar uma nova venda Pendente (Cliente 1, Produto A qtd 1).
2. Definir o modo: `curl "http://127.0.0.1:8080/_modo?m=offline-simulado"`.
3. Abrir a venda > Confirmar venda e confirmar no diálogo.

Esperado: idem B.

**E) Reenviar pela fila**
1. Com um item na fila (de B, C ou D), voltar o mock a ok: `curl "http://127.0.0.1:8080/_modo?m=ok"`.
2. Pendências > selecionar o item > Reenviar selecionado.
3. Repetir com o mock ainda em falha (ex.: `curl "http://127.0.0.1:8080/_modo?m=erro500"`) em outro item.

Esperado: (1-2) item concluído, venda Quitada, e-mail e PDF enviados (como C5), contador decrementa; (3) com o mock ainda em falha: "Ainda não foi possível reenviar este item. Tente novamente." e o item permanece.

**F) Timeout após gravação (opcional)**: `m=timeout-post` está descrito em C8 (e no README de `tools/mock-financeiro`); siga os passos e o esperado de lá.

## C7. Falha de SMTP -> fila EMAIL
Dado: mock `ok`; senha SMTP errada no INI (ou `ERPV_SMTP_PASSWORD` inválida); nova venda Pendente.
1. Confirmar a venda.
2. Corrigir a senha SMTP; reiniciar o sistema; Pendências > Reenviar o item de e-mail.

Esperado: (1) venda Quitada (Financeiro confirmou); aviso de que o e-mail não foi enviado ("... Ele ficou na fila; reenvie em Pendências."); item tipo EMAIL na fila com último erro "Falha SMTP ..." (sem senha no log); (2) e-mail chega ao Mailtrap com PDF regenerado; item concluído; sem novo POST de quitação.

## C8. Reconciliação
Dado: `m=timeout-post`; nova venda Pendente.
1. Confirmar a venda (o POST estoura por timeout, mas o mock já registrou a quitação).
2. Trocar para `m=ok`; Pendências > Reenviar o item.

Esperado: (1) venda continua Pendente e item na fila; (2) o sistema consulta `GET /api/vendas/N/status`, encontra Quitada e conclui localmente, sem novo POST (log do mock com 1 POST); venda Quitada; item concluído (nota "reconciliada pela fila de pendências"); e-mail enviado.

## C9. Cancelamento
Dado: mock `ok`; uma venda Pendente; uma Quitada.
1. Venda Pendente > Cancelar venda; conferir o campo "Motivo (opcional)" e o texto de apoio "Não informe dados pessoais (CPF, telefone, e-mail) no motivo."; preencher um motivo (ex.: "Cliente desistiu") > "Confirmar cancelamento". Repetir em outra Pendente sem motivo.
2. Repetir com `m=recusa` e com `m=erro500` em outras Pendentes.
3. Tentar cancelar a Quitada e uma já Cancelada.
4. Conferir no banco: `SELECT MOTIVO_CANCELAMENTO FROM VENDAS WHERE ID = N`.
5. No cancelamento que foi para a fila (`m=erro500`, com motivo preenchido), voltar `m=ok` e Pendências > Reenviar selecionado; conferir de novo `VENDAS.MOTIVO_CANCELAMENTO`.

Esperado: (1) status Cancelada, somente leitura; mock recebeu POST `/api/vendas/cancelamento`; (2) recusa: "Cancelamento recusado pelo Financeiro ..." e venda continua Pendente; 500: "Financeiro indisponível. O cancelamento da venda N foi colocado na fila de pendências", e Reenviar depois conclui; (3) "Venda já quitada não pode ser cancelada" / "Venda já está cancelada"; (4) cancelamento com motivo grava o texto em `VENDAS.MOTIVO_CANCELAMENTO` (recortado em 255 caracteres); sem motivo fica NULL; (5) o reenvio pela fila conclui o cancelamento mas grava `MOTIVO_CANCELAMENTO` NULL: o motivo não é persistido na `FILA_INTEGRACAO` e o reenvio de CANCELAMENTO sai sem motivo (decisão RF10-02).

## C10. INI ausente ou inválido
Dado: `erpvendas.ini` removido; depois INI com chave obrigatória vazia (ex.: `BaseUrl=`); depois senha de banco errada.
1. Iniciar `ERPVendas.exe` em cada situação.

Esperado: diálogo de erro "Arquivo de configuracao nao encontrado: "<caminho>". Copie config\erpvendas.ini.example para essa pasta, ajuste os valores ... e inicie o sistema novamente." e encerramento sem abrir a janela principal; para chave vazia: `Configuracao invalida em "<ini>": chave "..." ausente ou vazia na secao ...`; para banco: mensagem amigável sem credencial. Nenhuma stack/SQL exibida.

## C11. Teclado
Dado: aplicação aberta na tela principal; clientes, produtos e ao menos uma venda de teste cadastrados; mouse fora de uso (apenas teclado).
1. Em cada edição modal (Cliente, Produto, Venda): percorrer com Tab; digitar e pressionar Enter; pressionar Esc.
2. Nas listas: Esc; atalhos Alt+letra (`&`) de botões e menus.
3. Na grade de itens da venda, pressionar Enter.

Esperado: foco inicial no 1º campo; TabOrder lógico (topo para base, sem campos ocultos); Enter = Salvar/OK no modal, exceto na grade de itens (não aciona Salvar); Esc = Cancelar/Fechar; Alt+letra aciona o botão/menu; foco visível.

## C12. Instalação em pasta limpa
Dado: máquina sem Delphi, com Firebird 3; pacote `bin/` (exe, `fbclient.dll` da mesma arquitetura, `libeay32/ssleay32`, `erpvendas.ini.example`, `db/`, README).
1. Restaurar `ERPVENDAS.FBK` com `gbak` (ou rodar os SQL 00/01/02).
2. Copiar `erpvendas.ini.example` para `erpvendas.ini`, ajustar, criar as pastas de log e PDF.
3. Executar `ERPVendas.exe`; percorrer C1, C3 e C5 (e-mail com TLS).

Esperado: abre sem DLL faltando; barra de status "Financeiro: <BaseUrl>"; seed visível (2 clientes, 3 produtos); log diário criado na pasta configurada; e-mail com TLS enviado; sem depender de ferramentas de desenvolvimento.
