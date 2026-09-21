# ADR-009 — Mock do Financeiro como script único fora do executável

- Status: Accepted (DEC-06 adotada, com escolha de tecnologia)
- Contexto: o C# pode atrasar (P-08); é preciso simular sucesso, recusa 4xx, 5xx e timeout.
- Alternativas: mock em Delphi/Indy (mais código no repositório principal, compila junto); Node (instalação extra); Python stdlib `http.server` (um arquivo, sem dependências, se Python já existir).
- Decisão: `tools/mock-financeiro/mock_financeiro.py`, Python 3 só stdlib, implementa as 3 rotas do contrato v1.0, guarda status em memória e aceita modo por parâmetro de linha de comando/rota administrativa `/_modo?m=ok|recusa|erro500|timeout|offline-simulado`. Não faz parte do pacote de entrega do exe (ferramenta de desenvolvimento/demo). Se Python indisponível: fallback é o próprio C# real ou parar o mock e demonstrar a fila.
- Consequências: (+) ~1 h de trabalho; (-) requer Python na máquina de dev/demo, registrado no README.
