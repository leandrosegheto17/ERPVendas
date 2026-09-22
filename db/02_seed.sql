-- =============================================================================
-- ERP Vendas (Delphi) - db/02_seed.sql
-- Tarefa: T04 (Lote 1) | Origem: SDD.md Secao 5/7
--
-- Seed minimo para desenvolvimento/demonstracao: 2 clientes (1 pessoa fisica,
-- 1 pessoa juridica) com CPF/CNPJ com digitos verificadores validos, e-mails
-- claramente de sandbox/teste, e 3 produtos. Todos os nomes/dados sao
-- ficticios (GUARDRAILS.md regra 18 - dados de demo ficticios).
--
-- Deve rodar APOS db/01_schema.sql, na mesma sessao ja conectada ao banco de
-- destino (nao conecta, nao cria banco, sem usuario/senha embutidos -
-- GUARDRAILS.md regra 16), por exemplo:
--   isql -user SYSDBA -password <senha> caminho\ERPVENDAS.FDB -i db\02_seed.sql
-- ou em modo embedded local:
--   isql caminho\ERPVENDAS.FDB -i db\02_seed.sql
-- =============================================================================

SET SQL DIALECT 3;

-- -----------------------------------------------------------------------------
-- CLIENTES (2) - CPF/CNPJ com digito verificador correto, e-mail sandbox
-- -----------------------------------------------------------------------------
INSERT INTO CLIENTES (NOME, TIPO_PESSOA, CPF_CNPJ, ENDERECO, TELEFONE, EMAIL, ATIVO)
VALUES ('Cliente Exemplo 1', 'F', '52998224725', 'Rua Ficticia, 100, Bairro Teste', '(11) 90000-0001', 'cliente.exemplo1@example.com', TRUE);

INSERT INTO CLIENTES (NOME, TIPO_PESSOA, CPF_CNPJ, ENDERECO, TELEFONE, EMAIL, ATIVO)
VALUES ('Empresa Exemplo 2 Ltda', 'J', '11222333000181', 'Av. Ficticia, 200, Sala 2, Bairro Teste', '(11) 90000-0002', 'contato.exemplo2@mailtrap-sandbox.test', TRUE);

-- -----------------------------------------------------------------------------
-- PRODUTOS (3) - descricao, unidade e preco NUMERIC(15,2)
-- -----------------------------------------------------------------------------
INSERT INTO PRODUTOS (DESCRICAO, UNIDADE, PRECO_UNITARIO, CATEGORIA, ATIVO)
VALUES ('Produto Exemplo A', 'UN', 19.90, 'Categoria Teste', TRUE);

INSERT INTO PRODUTOS (DESCRICAO, UNIDADE, PRECO_UNITARIO, CATEGORIA, ATIVO)
VALUES ('Produto Exemplo B', 'CX', 145.50, 'Categoria Teste', TRUE);

INSERT INTO PRODUTOS (DESCRICAO, UNIDADE, PRECO_UNITARIO, CATEGORIA, ATIVO)
VALUES ('Produto Exemplo C', 'KG', 8.75, 'Categoria Teste', TRUE);

COMMIT;

-- Fim de db/02_seed.sql
