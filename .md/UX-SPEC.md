# UX-SPEC — ERP Vendas (Delphi VCL) — v1.1 (2026-09-21, reabertura pontual: camada visual)

Wireframes em ASCII. Componentes DevExpress citados são candidatos, sem fixar versão (DEC-02). v1.1 (pedido do usuário: "interface clean e profissional"): fluxos, regras de status (§4.2), estados (§4.1) e textos (§4.3) NÃO mudaram; mudaram §2 (wireframes refinados), §3 (identidade visual, tema, layout, padrões), nova §8 (tokens/bases) e §9 (camadas de polimento, custo, riscos). Decisão registrada no ADR-011. Substitui o corte INT-06 "sem acabamento" apenas na camada MUST de §9; o resto do acabamento segue cortável.

## 1. Fluxos de Tela
```
Login: não existe (app monousuário)
[Menu Principal] --+--> [Clientes: Lista] <-> [Cliente: Edição (modal)]
                   +--> [Produtos: Lista] <-> [Produto: Edição (modal)]
                   +--> [Vendas: Lista] <-> [Venda: Mestre/Detalhe (modal)] --> Confirmar / Cancelar --> [Mensagens de desfecho]
                   |                              \--> [Seletor de Produto/Item (inline na grade de itens)]
                   +--> [Pendências de Integração] (Reenviar)
                   +--> Sair
```
Mapeamento de fluxos do PRD-TECNICO §4: cadastrar venda -> Venda Edição; Confirmar -> Venda Edição/Lista (ação); Cancelar -> idem; tratamento de fila -> Pendências; e-mail inválido/inexistente -> validação no Cliente (e-mail obrigatório) + falha de e-mail no desfecho; cliente/produto inativado -> aparece desabilitado nos lookups de venda e como "Inativo" nas listas.

Navegação: menu principal (dxBarManager/MainMenu) com formulário principal único; telas de lista abrem como formulários filhos (`Show`) e edições como modais (`ShowModal`). Barra de status mostra: "Financeiro: <BaseUrl>" e "Pendências: N" (clicável -> Pendências).

## 2. Wireframes

### 2.1 Menu principal
Shell "ribbon-less": faixa superior de marca + navegação lateral fixa (recomendada) OU menu de barra simples (fallback se a navegação lateral estourar prazo; mesmas opções e atalhos). Telas de lista abrem na área de conteúdo (formulário filho embutido, `Parent`/`Align=alClient`, ou MDI se mais barato na versão), uma por vez; edição/cancelamento seguem modais.
```
+-----------------------------------------------------------------------+
| [logo] ERP Vendas                                       (faixa 48 px) |  <- cor de destaque, texto branco
+------------------+----------------------------------------------------+
| (nav 200 px)     |  Área de conteúdo (fundo #F5F7FA, margem 16 px)    |
|  Cadastros       |                                                    |
|   [ic] Clientes  |   (cabeçalho de página + barra de ações + grade)   |
|   [ic] Produtos  |                                                    |
|  Vendas          |   Início sem tela aberta: título "Bem-vindo" +     |
|   [ic] Vendas    |   3 atalhos (Nova venda / Clientes / Pendências)   |
|  Integração      |                                                    |
|   [ic] Pendências|                                                    |
|   (N) chip       |                                                    |
|  Ajuda > Sobre   |                                                    |
+------------------+----------------------------------------------------+
| Financeiro: http://localhost:5000  |  Pronto  |  [!] Pendências: 2    |  <- status 24 px
+-----------------------------------------------------------------------+
```
Item de navegação ativo: fundo de seleção + barra de destaque à esquerda 3 px + texto em negrito (não só cor). Chip "N" só aparece se N > 0. Status bar: esquerda = ambiente; centro = estado ("Pronto" / "Aguardando Financeiro..."); direita = Pendências (clicável, com ícone e texto).

### 2.2 Lista de Clientes (padrão de lista para Produtos e Vendas)
Padrão de página (todas as listas): cabeçalho (título 20 px semibold + subtítulo/contagem em cinza) | barra de ações (primário à esquerda: [+ Novo]; secundários; perigoso à direita/separado) | filtros | grade em "cartão" (fundo branco, borda 1 px) | rodapé da grade com contagem.
```
+ Clientes                                                            +
|  Clientes                                                           |
|  2 registros                                                        |
|  [ + Novo ]  [ Editar ]  [ Inativar/Excluir ]          [ Fechar ]   |
|  [ Buscar por nome, documento ou e-mail... ]  [ ] Mostrar inativos  |
| +----+-------------------+----------------+---------------+-------+ |
| | Cód| Nome/Razão Social | CPF/CNPJ       | E-mail        | Situa.| |  <- cabeçalho claro, sem 3D
| |  1 | Ana Silva         | 123.456.789-09 | ana@x.com     | Ativo | |  <- linha branca
| |  2 | Acme Ltda         | 12.345.678/0001| fin@acme.com  | Inativo |  <- zebra sutil; texto cinza
| +----+-------------------+----------------+---------------+-------+ |
+---------------------------------------------------------------------+
Vazio:  (grade)   [ícone pasta]  "Nenhum registro. Use Novo."   (centralizado, cinza)
Erro:   banner vermelho no topo da página: "Não foi possível carregar a lista. Detalhes gravados no log." [Tentar novamente]
Carreg.: cursor de espera + grade esmaecida (consulta local; normalmente imperceptível)
```
"Situação" = chip de texto (Ativo = verde, Inativo = cinza), sempre com texto.
Componentes: cxGrid (TableView, somente leitura, filtro/busca no editor), cxTextEdit, cxCheckBox, cxButton. Excluir com vendas => informa "Cliente possui vendas e foi inativado" (RF-04).

### 2.3 Edição de Cliente
Padrão de edição: título do modal + subtítulo ("Novo cliente"/"Editar cliente"), rótulos ACIMA dos campos (coluna única, 1 campo por linha, largura total ou pares curtos), erro em texto vermelho abaixo do campo, rodapé com barra de botões separada por linha de 1 px: primário à direita, secundário à esquerda do primário.
```
+ Cliente ------------------------------------------------------[X]+
|  Novo cliente                                                    |
|  Tipo de pessoa   (o) Física   ( ) Jurídica                      |
|  Nome/Razão Social *                                             |
|  [____________________________________________________]         |
|  CPF/CNPJ *                       Telefone                       |
|  [___.___.___-__]                 [(__) _____-____]              |
|  x CPF inválido                                                  |
|  E-mail *                                                        |
|  [____________________________________________________]         |
|  Endereço                                                        |
|  [____________________________________________________]         |
|  [x] Ativo                                       * obrigatório   |
|  ------------------------------------------------------------    |
|                                  [ Cancelar ]  [ Salvar ]        |
+------------------------------------------------------------------+
```
Campo inválido: borda vermelha 1 px + texto abaixo com ícone (nunca só cor). Campo focado: borda de destaque 2 px.
Componentes: cxRadioGroup, cxTextEdit, cxMaskEdit (máscara CPF/CNPJ conforme tipo), cxCheckBox, TdxLayoutControl opcional, TcxButton. Produto: mesmo padrão com Descrição, Unidade, Preço (cxCurrencyEdit), Categoria (cxTextEdit), Ativo.

### 2.4 Lista de Vendas
```
+ Vendas                                                             +
|  Vendas                                                            |
|  2 vendas                                                          |
|  [ + Nova ]  [ Abrir ]  [ Confirmar ]  [ Excluir ]      [ Fechar ]|
|  Status [Todos v]   Cliente [ Buscar cliente...        ]           |
| +----+------------+--------------+-----------+-----------+------+  |
| | Nº | Data       | Cliente      |     Total | Status    | Sinc |  |  <- valores numéricos alinhados à direita
| | 10 | 21/09/2026 | Ana Silva    |    350,00 | Pendente  | [!]  |  |
| |  9 | 20/09/2026 | Acme Ltda    |  1.200,00 | Quitada   |      |  |
| +----+------------+--------------+-----------+-----------+------+  |
+--------------------------------------------------------------------+
```
"Cancelar venda" fica dentro da própria venda (Abrir) e no menu de contexto da linha, por ser perigosa (não como botão de destaque na barra). Confirmar continua na barra (ação principal da venda Pendente). Status = chip (texto + cor de fundo suave, §3.1). Sinc = ícone [!] âmbar + tooltip "Sincronização pendente" (derivado da fila, INT-03). Botões habilitados por status (§4.2). Vazio: "Nenhum registro. Use Novo." Erro: banner como na lista de Clientes.
Coluna "Sinc" com símbolo (!) + tooltip "Sincronização pendente" (derivado da fila; não é status, INT-03). Botões habilitados por status (ver 4.2). Cores de status sempre acompanhadas do texto.

### 2.5 Venda — Mestre/Detalhe
```
+ Venda ------------------------------------------------------[X]+
|  Venda nº 10                                  [ PENDENTE ]       |  <- chip de status no cabeçalho
|  (banner, só se Quitada/Cancelada/fila pendente: ver abaixo)     |
|  Cliente *                          Data          Quitada em     |
|  [Ana Silva (123.456.789-09)   v]   [21/09/2026]  --/--/----     |
|  Itens                                     [ + Adicionar ] [ Remover ]|
|  +----------------------+-----+------------+------------+       |
|  | Produto              | Qtd | Preço unit |   Subtotal |       |
|  | Caneta azul (UN)     |  10 |       2,50 |      25,00 |       |
|  | Caderno (UN)         |   5 |      65,00 |     325,00 |       |
|  +----------------------+-----+------------+------------+       |
|                                   Total    R$ 350,00  (24 px, negrito, somente leitura)
|  ------------------------------------------------------------   |
|  [ Cancelar venda ]  (texto vermelho)   [ Fechar ] [ Salvar ] [ Confirmar venda ]|
+------------------------------------------------------------------+
```
Hierarquia de botões: primário preenchido = Confirmar venda (em venda Pendente com itens) e Salvar como secundário forte (contorno); Fechar neutro; Cancelar venda = botão perigoso (contorno/texto vermelho), afastado à esquerda. Confirmar/Cancelar continuam sujeitos a §4.2. Banners (linha única, ícone + texto, fundo suave): Quitada/Cancelada = info "Venda Quitada/Cancelada: somente leitura"; fila pendente = aviso "Há uma operação pendente no Financeiro. Use Pendências."; total e valores alinhados à direita.
Componentes: cxLookupComboBox (clientes ativos), cxGrid editável para itens (cxLookupComboBox de produto ativo, cxSpinEdit qtd inteira >0, preço unitário somente leitura copiado do produto no add, subtotal calculado), cxCurrencyEdit/cxLabel total somente leitura, cxButtons. Preço unitário não editável (RN-04 snapshot). Total recalculado a cada mudança de item.

Venda não Pendente: todos os controles de edição desabilitados, itens somente leitura, Salvar/Confirmar/Cancelar escondidos ou desabilitados, banner "Venda Quitada/Cancelada: somente leitura".

### 2.6 Diálogo de cancelamento
```
+ Cancelar venda nº 10 -------------------------------------+
| Motivo (opcional): [_____________________________________]|
|                               [Confirmar cancelamento] [Voltar]|
+-----------------------------------------------------------+
```

### 2.7 Pendências de Integração
```
+ Pendências de Integração                                            +
|  Pendências de Integração                                           |
|  2 itens aguardando reenvio                                         |
|  [ Reenviar selecionado ]  [ Atualizar ]  [ ] Somente pendentes  [ Fechar ]|
|  ("Reenviar todos" = P2, entra à direita do primário se existir)    |
| +-------+----------+-------------+-------+-----------+-----------------------+
| | Venda | Tipo     | Criado em   | Tent. | Situação  | Último erro           |
| |   10  | Quitação | 21/09 10:02 |     1 | Pendente  | Timeout (10 s)        |
| |    9  | E-mail   | 20/09 15:40 |     2 | Pendente  | Falha no envio SMTP   |
| +-------+----------+-------------+-------+-----------+-----------------------+
+---------------------------------------------------------------------+
Vazio: [ícone check verde] "Nenhuma pendência."   Erro: banner vermelho + [Tentar novamente]
```
Componentes: cxGrid somente leitura, cxButtons. "Reenviar todos" é P2 (cortável); MVP = Reenviar selecionado. Resultado de cada reenvio em mensagem-resumo.

## 3. Design System
Não há design system prévio; define-se um mínimo (identidade + tema único + padrões), implementável com DevExpress VCL/VCL padrão, sem recurso exclusivo de versão. Fonte única dos valores: unit de tokens (§8).

### 3.1 Identidade visual mínima
**Paleta** (contraste calculado sobre a superfície indicada; confirmar com verificador de contraste na T-tokens; alvo WCAG AA: texto normal >= 4,5:1, texto grande/UI >= 3:1):
| Token | Hex | Uso | Contraste |
|---|---|---|---|
| Fundo app | #F5F7FA | fundo da área de conteúdo | - |
| Superfície | #FFFFFF | grades, modais, cartões | - |
| Borda | #CBD2D9 | grade, campos, divisórias | UI >= 3:1 só p/ campos (usar #9AA5B1 na borda de campo) |
| Texto principal | #1F2933 | corpo | ~14:1 sobre branco |
| Texto secundário | #52606D | subtítulos, cabeçalho de coluna, inativo | ~6,5:1 |
| Destaque (1 cor) | #1F6FB2 | faixa de marca, botão primário, foco, item ativo | ~5,3:1 com texto branco |
| Destaque hover/pressionado | #185A92 | estados do primário | > 7:1 com branco |
| Seleção de linha | #DCEBFA | linha selecionada (texto principal mantido) | > 10:1 |
| Zebra | #F8FAFC | linhas alternadas (sutil) | - |
| Sucesso | texto #1E7B3A / fundo #E6F4EA | Quitada, Ativo, sucesso | >= 4,5:1 |
| Aviso | texto #8A5300 / fundo #FFF4DB | Pendente, Sinc, aviso | >= 4,5:1 |
| Erro/perigo | texto/borda #B3261E / fundo #FDECEA | erro, Cancelar venda, campo inválido | >= 4,5:1 |
| Info | texto #0B5E8E / fundo #E5F1FA | banner informativo | >= 4,5:1 |
| Cancelada/Inativo | texto #52606D / fundo #EDEFF2 | Cancelada, Inativo | >= 4,5:1 |
Status de venda (chip = fundo suave + texto colorido + texto do status): Pendente=aviso, Quitada=sucesso, Cancelada=cinza. Cor nunca é o único portador de significado.

**Tipografia:** fonte do sistema Segoe UI (fallback Tahoma; sem fontes embutidas). Escala: corpo 9 pt (12 px), rótulo de campo 9 pt semibold, cabeçalho de coluna 9 pt semibold cor secundária, subtítulo 10 pt, título de página 14 pt semibold, total da venda 16 pt bold, faixa de marca 12 pt semibold. Definida em pontos (escala com DPI).

**Espaçamento (grid de 8 px):** tokens 4 / 8 / 16 / 24. Margem da página 16; entre campos 8 (rótulo→campo 4); entre grupos 16; altura de controle 28 px (botão e editor); altura de linha de grade 28 px; altura da barra de ações 40; faixa de marca 48; status bar 24; navegação lateral 200 px, item 36 px.

**Raio/bordas:** raio 4 px em botões/campos/chips (se o skin não suportar, aceita o do skin); borda 1 px #CBD2D9; sem sombras próprias, sem gradientes, sem bordas 3D.

**Densidade:** confortável-compacta (linha 28 px) para caber 15+ linhas em 1366x768; uma única densidade em todo o app.

**Ícones:** um único conjunto livre, traço fino monocromático, MIT/ISC (candidatos: Tabler Icons MIT, Lucide ISC), exportados uma vez para PNG 16 px e 24 px (+32 px para DPI alto) numa TImageList/cxImageList central; cor #52606D (branco na faixa de marca, #FFFFFF no item ativo se fundo escuro). Máximo ~14 ícones: novo, editar, excluir, salvar, fechar, confirmar, cancelar, buscar, atualizar, reenviar, alerta, erro, info, sucesso, pasta/vazio. Não usar a biblioteca de ícones da DevExpress (licença/edição variável) nem imagens de licença desconhecida; registrar a licença do conjunto no `docs/ambiente-licencas.md`. Todo botão com ícone mantém o texto (acessibilidade).

### 3.2 Tema/skin DevExpress (único, centralizado)
- Um único ponto de aplicação: no composition root/form principal, criar 1 controller de skin (dxSkinController / `TdxSkinController`) + 1 LookAndFeel controller (`TcxLookAndFeelController`) e definir o tema uma vez; nenhum form define skin/estilo próprio (`ParentFont`/LookAndFeel herdado).
- Escolha do skin (decidir no T01, com o que o trial instalado realmente contém): ordem de preferência por look claro, plano e moderno: "Office2019Colorful"/"Office2016Colorful"/"Office2013White"/"Basic"/"Metropolis"/"VS2010". Tentar em ordem; usar o primeiro que a versão instalada aceitar (checando os skins linkados/registrados; unidades `dxSkin*` precisam estar no `uses` do projeto).
- Fallback: se nenhum skin existir/carregar (ou o controller não existir na edição/trial), usar LookAndFeel nativo `Kind = lfUltraFlat` (ou `lfFlat`) com `NativeStyle=False` e aplicar o resultado visual pelos tokens (§8) via estilos (`TcxStyleRepository` central: fundo, cabeçalho, zebra, seleção, foco). O resultado é aceitável e o app nunca falha por causa do skin. Registrar o skin efetivo em `docs/ambiente-licencas.md`.
- cxGrid: `TableView` sem indicador, sem agrupamento/rodapé desnecessários, `Options.CellSelect` conforme tela, linhas 28 px, cabeçalho plano cor secundária semibold sem 3D, zebra #F8FAFC, seleção #DCEBFA (texto principal), sem linhas verticais fortes (só horizontais 1 px #E4E7EB), números à direita, `NoDataToDisplayInfoText` do §4.1, `Options.Editing=False` nas listas. Configuração feita por um helper único da base de lista (`ConfigurarGrade`), não por tela.
- Editores: altura 28 px, borda de campo #9AA5B1, foco = borda de destaque 2 px (`StyleFocused`), inválido = borda #B3261E (`StyleValidate/ErrorIcon` ou estilo próprio); desabilitado = fundo #EDEFF2 + texto secundário.
- Botões: primário preenchido (destaque, texto branco), secundário contorno (borda #9AA5B1, texto principal), perigoso contorno vermelho (texto #B3261E), todos com foco visível (retângulo de foco/borda 2 px). Usar `TcxButton` com estilos do repositório central; se o skin já entregar bom resultado, apenas marcar o primário.
- Nada depende de recurso exclusivo de versão (ex.: paletas dinâmicas, ribbon, `TdxNavBar` moderno): navegação lateral cai para menu de barra simples (§2.1) se o componente não estiver no trial.

### 3.3 Padrões de layout e ação
- **Botão primário/secundário/perigoso:** primário sempre o mais à direita no rodapé de modal e o primeiro (esquerda) na barra de ações de lista; secundário ao seu lado; perigoso separado espacialmente (esquerda no rodapé do modal, direita na barra de lista), nunca preenchido, sempre com confirmação.
- **Cabeçalho de página:** título + subtítulo/contagem; sem barra de título customizada.
- **Barra de ações:** altura 40, ícone 16 px + texto, mesma ordem em todas as listas: Novo, Editar, [ação específica], Excluir/Inativar, espaço, Fechar. Botões indisponíveis ficam desabilitados (cinza), não escondidos, exceto venda não Pendente (§2.5).
- **Feedback (padrão único):** (a) Pergunta de confirmação e Erro e Aviso importante (falha de e-mail, Financeiro indisponível, recusa) = diálogo modal (`MessageDlg`/`TaskDialog` do sistema, ícone correspondente, botões em português "Sim/Não", "OK"); (b) Sucesso/Info simples (salvo, venda quitada com e-mail enviado, cancelamento OK, reenvio OK) = banner inline não bloqueante no topo da página/janela (ícone + texto, fundo suave, some em ~6 s ou ao clicar) e mesma frase na status bar; fallback se o banner atrasar: `MessageDlg` informativo. (c) Erro de campo = inline (§5). Textos de §4.3 permanecem literais; só o veículo (modal/banner) é definido aqui: Info = banner; Aviso/Erro/Pergunta = modal. Um único helper `Notificar(tipo, texto)` centraliza isso (§8).
- **Diálogos:** centralizados no form pai, largura fixa 480-560 px, mesmo rodapé de botões de §2.3; cancelamento (§2.6) segue o padrão de edição.
- **Novos componentes (sinalizados):** `TFormBaseLista`, `TFormBaseEdicao` **[NOVO]**, helper de notificação/banner **[NOVO]**, chip de status na grade (via estilo de célula, não componente), indicador "Sinc" (ícone na coluna) **[NOVO]**, unit de tokens **[NOVO]**. Nenhum componente de terceiros fora de DevExpress/VCL.
- Erros de campo: ver §5.

## 4. Estados de Tela
### 4.1 Padrão por tela
| Tela | Vazio | Carregando | Erro | Sucesso |
|---|---|---|---|---|
| Listas (Clientes/Produtos/Vendas) | Grade com texto "Nenhum registro. Use Novo." (NoDataToDisplayInfoText) | Cursor de espera (consulta local rápida; não aplicável barra de progresso) | Mensagem amigável + log (falha de banco) | Grade atualizada após salvar; linha selecionada |
| Edição Cliente/Produto | Campos em branco (novo) | Não aplicável (dado local, instantâneo) | Marcação do campo + mensagem (ver 5) | Fecha modal e lista atualizada; sem popup extra |
| Venda mestre/detalhe | Grade de itens vazia + total 0,00; Salvar recusa sem itens | Cursor de espera + botões desabilitados durante chamada ao Financeiro | Mensagens 4.3 | Mensagens 4.3 |
| Pendências | "Nenhuma pendência." | Cursor de espera durante reenvio | Coluna Último erro | Item some do filtro "somente pendentes" (CONCLUIDO) |

### 4.2 Habilitação por status da venda
| Status | Salvar/Editar/Excluir | Confirmar | Cancelar venda |
|---|---|---|---|
| Pendente (sem fila pendente) | sim | sim | sim |
| Pendente com QUITACAO/CANCELAMENTO na fila | não (decisão: edição bloqueada, há operação em curso no Financeiro) | não (usar Pendências) | não |
| Quitada | não | não | não (INT-05) |
| Cancelada | não | não | não |

### 4.3 Mensagens de desfecho (texto proposto)
| Situação | Tipo | Texto |
|---|---|---|
| Quitada + e-mail enviado | Informação | "Venda 10 quitada. Relatório enviado para ana@x.com." |
| Quitada + falha de e-mail | Aviso | "Venda 10 quitada, mas o e-mail não pôde ser enviado. Ele ficou na fila; reenvie em Pendências." |
| Financeiro indisponível/timeout | Aviso | "Financeiro indisponível. A venda 10 continua Pendente e foi colocada na fila. Tente novamente em Pendências." |
| Quitação recusada (4xx) | Erro | "Quitação recusada pelo Financeiro: <mensagem do Financeiro>. A venda continua Pendente." (sem fila) |
| Cancelamento OK | Informação | "Venda 10 cancelada." |
| Cancelamento recusado (dcRecusada) | Erro | "Cancelamento recusado pelo Financeiro: <mensagem do Financeiro>. A venda continua Pendente." (sem ": <mensagem>" se vazia; sem fila) — texto adotado em T44/RF10-03 |
| Cancelamento com Financeiro indisponível (dcEnfileirada) | Aviso | "Financeiro indisponível. O cancelamento da venda 10 foi colocado na fila e a venda continua Pendente. Tente novamente em Pendências." — texto adotado em T44/RF10-03 |
| Cancelamento, resposta inválida (dcRespostaInvalida) | Erro | "Resposta inesperada do Financeiro. Venda mantida como Pendente." — texto adotado em T44/RF10-03 |
| Cancelamento não permitido (dcNaoPermitida) | Aviso | Exibe a Mensagem do service (abaixo); se vazia, "A venda não pode ser cancelada." — texto adotado em T44/RF10-03 |
| Mensagens do service para dcNaoPermitida (sem texto próprio na UI, só a Mensagem) | Aviso | "Venda não encontrada"; "Venda já quitada não pode ser cancelada"; "Venda já está cancelada"; "Há uma operação pendente de envio ao Financeiro para esta venda. Resolva em Pendências antes de continuar."; "Não foi possível verificar operações pendentes. Tente novamente."; "Financeiro indisponível e não foi possível colocar o cancelamento na fila; a venda continua Pendente. Tente novamente mais tarde"; "O cancelamento foi confirmado no Financeiro, mas não foi possível gravá-lo localmente; a venda continua Pendente" + "; o cancelamento foi colocado na fila de pendências" ou " e não foi possível colocá-lo na fila; tente novamente mais tarde" — texto adotado em T44/RF10-03 |
| Diálogo de cancelamento: apoio LGPD (sob "Motivo (opcional)") | Texto de apoio | "Não informe dados pessoais (CPF, telefone, e-mail) no motivo." — texto adotado em T44/RF10-03 |
| Reenvio OK | Informação | "Item concluído." / falha: "Ainda não foi possível: <último erro>." |
| Confirmação antes de quitar | Pergunta | "Confirmar a venda 10 (R$ 350,00)? Esta ação envia a quitação ao Financeiro." |
| Erro inesperado | Erro | "Ocorreu um erro inesperado. Os detalhes foram gravados no log." |
| Resposta inválida do Financeiro | Erro | "Resposta inesperada do Financeiro. Venda mantida como Pendente." (+ log) |

## 5. Acessibilidade (aplicável a desktop VCL; WCAG como referência, critério mínimo)
- Toda ação por teclado: ordem de tabulação (TabOrder) lógica; Enter = Salvar/OK no modal, Esc = Cancelar/Fechar; teclas de atalho (`&`) em rótulos de botão e menu.
- Rótulos visíveis associados a cada campo (TLabel.FocusControl); campos obrigatórios com asterisco e texto "* obrigatório".
- Não depender só de cor: status e erro têm texto/ícone além da cor; contraste AA conforme paleta de §3.1 (proibido usar cor fora da tabela de tokens; texto secundário nunca abaixo de #52606D sobre branco).
- Foco visível em todo controle (borda 2 px de destaque); alvo mínimo 28 px de altura; navegação lateral operável por Alt+letra/setas.
- Foco visível e retorno do foco ao campo com erro após validação.
- Tamanho de fonte respeitando DPI do Windows (`Scaled=True`, `PixelsPerInch` consistente).
- Mensagens de erro em texto legível (compatível com leitores de tela via MessageDlg padrão).
- Pendências: nenhuma crítica identificada; revisão manual no roteiro de testes (navegar todas as telas só por teclado).

### Validação visual de CPF/CNPJ e e-mail
- Validação ao sair do campo (OnExit/OnValidate do cxEdit) e ao Salvar; regra real no Service (`EValidacao`), UI só apresenta.
- Estado inválido: borda vermelha (Style/StyleFocused ou `ErrorIcon` do DevExpress) + texto abaixo do campo ("CPF inválido", "CNPJ inválido", "E-mail inválido", "Campo obrigatório", "Documento já cadastrado"); foco vai ao primeiro campo inválido; Salvar bloqueado.
- Estado válido: sem indicação (ou ícone discreto de check, P2).
- Máscara segue o tipo de pessoa (CPF 000.000.000-00 / CNPJ 00.000.000/0000-00); troca de tipo limpa a máscara e revalida.

## 6. Comportamento Responsivo
Aplicação desktop VCL Windows. Responsivo = não aplicável para web/mobile. Requisitos: forms redimensionáveis com `Anchors`/`Align` (grades expandem, botões ancorados), tamanho mínimo 1024x600, sem rolagem horizontal em 1366x768; navegação lateral fixa (não recolhe no MVP); edições modais de tamanho fixo. Escala de DPI suportada (ver 5): alturas/larguras em tokens escaláveis (multiplicar por `Screen.PixelsPerInch/96` na unit de tokens, não pixels fixos soltos nos forms); layout validado em 100% e 125% (150% best effort); ícones 16/24/32 px escolhidos por DPI.

## 7. Restrições Técnicas Aplicadas (autochecagem contra SDD.md)
| Restrição do SDD | Efeito na UX | Decisão / trade-off |
|---|---|---|
| Chamada síncrona ao Financeiro (ADR-004, timeout 10 s) | UI pode ficar não responsiva até 10 s | Cursor de espera, botões desabilitados, texto "Aguardando Financeiro..." na barra de status; sem barra de progresso/cancelar (custo alto no D4). Aceito, detalhe |
| Sem auto-retry (ADR-005) | Usuário precisa reenviar | Contador de pendências na status bar + indicador na lista de vendas; "Reenviar todos" P2 |
| "Sincronização pendente" não é status (INT-03) | Só 3 status na UI | Indicador derivado da fila, coluna "Sinc" |
| Só Pendente edita/cancela (RN-02/DEC-09) | Ações desabilitadas por status | Ver 4.2; sem cancelar venda Quitada |
| Recusa 4xx sem corpo garantido (v1.1 não confirmada) | Mensagem do Financeiro pode não existir | Texto genérico "Quitação recusada pelo Financeiro (código HTTP xxx)" como fallback |
| Preço snapshot, total calculado (RN-04) | Preço e total não editáveis | Campos somente leitura |
| Sem login | Sem tela de autenticação | n/a |
| Log/erros centralizados (ADR-008) | Mensagens genéricas para erros inesperados | Texto padrão + log |
| PDF não persistido (SDD §4) | Sem botão "abrir PDF anterior" no MVP | Opcional P2: "Visualizar relatório" regenera e abre; não previsto no PRD, sinalizado como sugestão |
| Componentes DevExpress sem versão fixa | Nomes de componentes podem mudar | Lista de candidatos, sem dependência de recurso específico |
| Skin/tema DevExpress no trial (v1.1) | Skin pode não existir/carregar | Lista de preferência + fallback lfUltraFlat com estilos por tokens (§3.2); ADR-011 |
| Sem threads (DEC-14) | Banner "Aguardando Financeiro..." não anima | Texto estático na status bar + cursor de espera |
Nenhum trade-off exige decisão do Gestor por si só; o custo adicional da v1.1 (~7 h MUST, ~12 h com SHOULD, §9) soma-se ao risco RP-1 já sinalizado no TASK.md e é decisão do usuário/Gestor; exceto item opcional "Visualizar relatório" (fora do PRD; só se sobrar tempo, decisão do Gestor).

## 8. Design tokens e bases de form
**Unit única `ERPV.UI.Tokens`** (em `src/UI`, só constantes e funções triviais, sem regra de negócio): cores (todas as da tabela §3.1 como `TColor`), fonte (nome e tamanhos em pontos), espaçamento (4/8/16/24, altura de controle 28, barra 40, faixa 48, status 24, nav 200) com função de escala por DPI, raio, nomes de ícone. Toda cor/tamanho usado em `.pas`/`.dfm` novo vem daqui (ou herdado da base); valor solto no form é reprovado em revisão.
**Unit `ERPV.UI.Tema`** (aplicação): `AplicarTema` (skin + fallback, §3.2), `ConfigurarGrade(View)`, `EstilizarBotao(Btn, Papel)` (Papel: Primario/Secundario/Perigoso), `Notificar(Tipo, Texto)` (banner/modal, §3.3). Chamada uma vez no arranque; bases chamam os helpers.
**`TFormBaseLista`** [NOVO]: título/subtítulo/contagem, barra de ações padrão (Novo/Editar/Excluir/Fechar + ganchos), grade com `ConfigurarGrade`, banner de notificação, vazio/erro padrão, Esc fecha. **`TFormBaseEdicao`** [NOVO]: título/subtítulo, corpo em coluna única, rodapé com Cancelar/Salvar, Enter/Esc, foco no 1º campo, exibição de erro de campo padrão (`MostrarErroCampo`).
**Promoção de "cortável" para recomendada (P1, e MUST dentro da camada visual):** custo ~3 h (T15) + ~2 h de helpers; benefício: 6 telas (T19/T20/T23/T24/T31/T32) herdam identidade, Enter/Esc, banner e estados sem repetir; sem a base cada tela custa ~0,5-1 h a mais (~4 h) para ficar visualmente igual e a inconsistência vira retrabalho na T60. Saldo líquido de prazo ~neutro; ganho de qualidade alto. Se cortada, as constantes de tokens e o `Tema` continuam valendo (aplicação manual por tela).

## 9. Camadas de polimento, custo e riscos
| Camada | Itens | Horas aprox. (a mais que o TASK atual) |
|---|---|---|
| MUST | (1) `ERPV.UI.Tokens`; (2) `ERPV.UI.Tema`: skin único + fallback + `ConfigurarGrade` + `EstilizarBotao` + `Notificar`; (3) bases de form promovidas e com padrão visual/§3.3; (4) consistência: paleta/tipografia/espaçamento/estados/botões nas 6 telas + shell; (5) validação DPI 100/125% | ~7 h (tokens 1 + tema 2,5 + bases +2 sobre T15 + shell layout/faixa/status +1 sobre T14 + margem) |
| SHOULD | navegação lateral com item ativo/chip (senão menu de barra); conjunto de ícones 14 PNG + `cxImageList`; chips de status/Situação na grade; banners inline (senão `MessageDlg`); tela inicial de boas-vindas | ~5 h |
| Cortável (acabamento) | ícone de check de validação, tooltips ricos, animação/auto-hide sofisticado do banner, ícones em 32 px extras, item recolhível na navegação, "Reenviar todos", atalhos/máscaras extras, tela de boas-vindas | ~5 h (já em T66) |
Total: MUST ~7 h; MUST+SHOULD ~12 h; tudo ~17 h. Como fração do orçamento efetivo de 30-45 h do dev (TASK §5 RP-1), MUST é o mínimo defensável para "clean e profissional"; SHOULD só se o D2-D3 fechar no plano.
**Riscos:** (R-UX-1) skin ausente no trial -> fallback §3.2 (impacto baixo, ~1 h extra de estilos). (R-UX-2) DPI/alta resolução quebrando layout -> tokens escaláveis + `Scaled=True` + teste em 125%; 150%+ best effort. (R-UX-3) navegação lateral/`TdxNavBar` indisponível ou instável -> menu de barra (mesmo conteúdo). (R-UX-4) pressão de prazo D4: polimento nunca bloqueia P0 funcional; corte em ordem: cortável -> SHOULD -> (só então) MUST-4 parcial; tokens+skin+fallback nunca cortar (custo mínimo, benefício máximo). (R-UX-5) licença dos ícones -> só MIT/ISC, registrar. (R-UX-6) contraste calculado à mão -> conferir com verificador na tarefa de tokens.
