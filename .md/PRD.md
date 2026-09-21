# PRD — ERP Vendas (Delphi) — RASCUNHO v0.1 (2026-09-21)

Fonte: `.md/VISAO-PRODUTO.md`. Gate 1: Aprovado com ressalvas (`CTO-REVIEW.md`).
Legenda: [OBR] requisito do desafio; [SUG] sugestão do autor.

## 1. Problema e Contexto
A CartSys avalia candidatos (vaga Programador Delphi e C# Sênior/Especialista) por meio de um desafio de 7 dias: construir o módulo ERP Vendas (desktop Delphi) que cadastra clientes, produtos e vendas, delega a quitação/cancelamento ao ERP Financeiro (C#, desenvolvido em paralelo em outro repositório, via API REST JSON), emite o relatório de confirmação de pedido e o envia por e-mail após a quitação. Critérios de avaliação: padrão de desenvolvimento, raciocínio, boas práticas e maturidade técnica. Contexto: prazo de desenvolvimento de 5 dias (D1 = seg 21/09, entrega sexta 25/09/2026, sem folga; o prazo formal do desafio, 28/09, deixa de ser a referência), custo zero de licenças, dependência de um sistema paralelo.

## 2. Público-Alvo
- Primário: avaliadores técnicos da CartSys que lerão código, documentação e executarão/inspecionarão a entrega.
- Secundário (usuário funcional simulado): operador de vendas de uma empresa (sem autenticação/multiusuário no escopo).
- Par técnico: desenvolvedor do ERP Financeiro (C#), consumidor/provedor do contrato.

## 3. Objetivo de Sucesso (mensurável)
Até sexta 25/09/2026 (D4 = 24/09 feature freeze; D5 = integração final, docs e pacote):
1. 100% dos itens [OBR] (seção 5) atendidos e demonstráveis; baseline 0.
2. Fluxo ponta a ponta executado com sucesso ao menos 1 vez contra o Financeiro real (T17) e 1 vez contra o mock: cadastrar venda -> quitar -> status local "Quitada" -> PDF gerado -> e-mail recebido.
3. Cenários de falha (timeout, recusa 4xx) demonstrados: venda permanece Pendente com mensagem clara, sem travar o sistema.
4. Entregáveis completos: código-fonte, script DDL + `.FBK`, README de instalação/configuração, executável + DLLs, `docs/decisoes.md`, evidências (PDF, prints/vídeo).
5. Instalação validada em pasta limpa (D5).
6. Fallback: se o C# não estiver de pé na quinta, a demo usa o mock e a integração real entra como evidência adicional na sexta.

## 4. Escopo
**Dentro (esta fase):** CRUD Clientes, Produtos e Vendas; relatório de confirmação (ReportBuilder); e-mail automático pós-quitação; integração REST com o Financeiro; documentação e pacote de entrega. [OBR]. Extras [SUG]: fila de reenvio e tela de pendências, mock do Financeiro, log/tratamento central de exceções, validação CPF/CNPJ/e-mail, roteiro de testes.

**Fora (justificativa):**
- Autenticação/multiusuário: fora do escopo do desafio.
- Controle avançado de estoque / saldo (DEC-11): corta tempo, não exigido.
- Emissão fiscal NF-e/NFC-e: fora do escopo.
- Estorno de venda quitada (DEC-09): processo distinto.
- Reprocessamento automático da fila: cortado (prazo de 5 dias); a fila terá só o botão "Reenviar".
- Acabamento de UI (filtros, atalhos, máscaras): cortado.
- Roteiro de testes: enxuto (só o fluxo principal e as falhas).
- Seed extenso e refinamentos de contrato além de C1-C3: cortar se o prazo apertar.

## 5. Requisitos de Alto Nível e Prioridade
P0 = obrigatório; P1 = sugestão de alto retorno; P2 = acabamento.

| ID | Funcionalidade | Tipo | Prio | Justificativa |
|---|---|---|---|---|
| RA-01 | Ambiente sem custo funcional (Delphi, FireDAC, Firebird 3, DevExpress, ReportBuilder) | OBR | P0 | Sem stack nada compila |
| RA-02 | CRUD Clientes | OBR | P0 | Requisito explícito |
| RA-03 | CRUD Produtos | OBR | P0 | Requisito explícito |
| RA-04 | CRUD Vendas mestre/detalhe com status | OBR | P0 | Núcleo do módulo |
| RA-05 | Confirmar/Cancelar venda via API do Financeiro | OBR | P0 | Fluxo principal |
| RA-06 | Relatório de confirmação de pedido (PDF) | OBR | P0 | Requisito explícito; PDF é pré-requisito do anexo |
| RA-07 | E-mail automático após quitação | OBR | P0 | Requisito explícito |
| RA-08 | Integração ponta a ponta com Financeiro real | OBR | P0 | Prova de maturidade dual-stack |
| RA-09 | Entregáveis: README, DDL, .FBK, executável | OBR | P0 | Sem eles a entrega é inválida |
| RA-10 | Tratamento central de exceções + log | SUG | P1 | Pesa em "boas práticas" |
| RA-11 | Validação CPF/CNPJ e e-mail | SUG | P1 | Qualidade de dados |
| RA-12 | Fila de reenvio + tela de pendências (só botão "Reenviar") | SUG | P1 | Resiliência demonstrável; versão mínima |
| RA-13 | Mock do Financeiro | SUG | P1 | Desbloqueia desenvolvimento paralelo |
| RA-14 | decisoes.md, roteiro de testes enxuto | SUG | P1 | Evidencia raciocínio |
| RA-15 | Acabamento de UI | SUG | P2 | CORTADO nesta fase (prazo de 5 dias) |

## 6. Premissas e Riscos de Produto
Prazo de validação relativo ao cronograma do VISAO-PRODUTO. Donos: Autor (Leandro), Dev C# (par do Financeiro), CartSys (recrutador).

| ID | Premissa/Risco | Dono | Prazo |
|---|---|---|---|
| P-01 | DEC-02: versões/edições/licenças exatas de Delphi, DevExpress, ReportBuilder e suficientes (PDF/e-mail sem limitação impeditiva); registrar edição/versão/validade na T01 | Autor | D1 (21/09) |
| P-02 | Executável em trial expirar antes da avaliação: risco BAIXO/mitigado (autor informa que 30 dias cobrem a entrega/avaliação). Resta registrar validade na T01 e citar a limitação no README | Autor | D1 (registro), D5 (README) |
| P-03 | DEC-08: Financeiro recusa quitação com 4xx + corpo de erro; venda permanece Pendente. Adotada no Vendas, NÃO confirmada pelo C# | Contato C# | Envio D1 (21/09); confirmação até 23/09 (D3) |
| P-04 | DEC-09: só Pendente pode ser cancelada; Financeiro responde 409 caso contrário. NÃO confirmada pelo C# | Contato C# | Envio D1; confirmação até 23/09 (D3) |
| P-05 | Contrato v1.1 (C1-C8) é só proposta; risco de divergência. Baseline v1.0 permanece o vigente | Autor | Enviar D1; resposta até 23/09 (D3) |
| P-06 | Prazo de desenvolvimento = sex 25/09 (DEC-12 decidida pelo autor); 5 dias, sem folga | Autor | Encerrada; acompanhar diariamente |
| P-07 | SMTP funcional (TLS/OpenSSL) para demo | Autor | D1/D2 (22/09) |
| P-08 | Financeiro real pode atrasar; mitigado por mock; integração real no D4, fechamento no D5; se não estiver de pé na quinta, demo com mock | Contato C# / Autor | D4 (24/09), D5 (25/09) |
| P-09 | Escopo dual-stack em 5 dias, risco ALTO de cronograma; ordem P0->P1->P2; D4 = feature freeze | Autor | contínuo |
| P-10 | Firebird 3.0 confirmado, banco segregado do Financeiro (DEC-01/05) | Autor | Encerrada |

Restrições a repassar ao Coordenador (não decididas aqui): arquitetura em 3 camadas, estrutura de pastas, modelo de dados, DEC-03/04/05/06/07/10/13/14 são PROPOSTAS do VISAO-PRODUTO para avaliação.

## 7. Perguntas em Aberto
1. DEC-02: quais versões/licenças exatas de Delphi, DevExpress e ReportBuilder?
2. A CartSys fornece licenças?
3. Quem é o contato do lado C# e qual o canal (confirmar DEC-08/DEC-09 e contrato v1.1 até 23/09)?
4. O e-mail leva o PDF em anexo? (INT-01, assumido sim)
