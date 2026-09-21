# ADR-003 — Acesso a dados: entidades para escrita, TFDQuery somente leitura para grades e relatório

- Status: Accepted (DEC-10 adotada, com ajuste) — complementado por ADR-010: o híbrido vale atrás de interfaces de repositório
- Contexto: cxGrid e ReportBuilder trabalham naturalmente com DataSet; edição exige regras e validação.
- Alternativas: só entidades (mapeamento verboso); só DataSet (regra vaza para form).
- Decisão: híbrido. Repositório expõe `Obter/Inserir/Atualizar/Inativar` com entidades (`TCliente`, `TProduto`, `TVenda`+itens) e `ListarParaGrade(filtro): TFDQuery`/`TFDMemTable` somente leitura. SQL parametrizado sempre (nunca concatenação). `Currency` no Delphi para valores. Grade nunca é editada direto no DataSet: edição passa por Service.
- Consequências: (+) rápido; DataSet do relatório vem do mesmo repositório (consistência com o registro); (-) vida útil do DataSet gerenciada pelo form (dono libera).
