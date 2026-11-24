-- ==========================================================================
-- PROJETO : A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)
-- SGBD    : MySQL / MariaDB (XAMPP)
-- ARQUIVO : 03_03_PERIODO_DATA_REFERENCIA.sql
-- ASSUNTO : Dimensao de tempo para as medidas de variacao mensal
--
-- PROBLEMA
--   SEG_PERIODO guarda mes e ano como numeros inteiros. As funcoes de
--   inteligencia de tempo do DAX (PREVIOUSMONTH, DATEADD, TOTALYTD) exigem
--   uma coluna de data e uma tabela marcada como tabela de datas.
--
-- SOLUCAO
--   Promover SEG_PERIODO a dimensao de tempo, em vez de criar uma dCalendario
--   paralela: a granularidade do fato JA e mensal e a ligacao com o fato JA
--   existe. Uma tabela a menos no modelo, um relacionamento a menos, nenhuma
--   chance de granularidade divergente.
--
--   No Power BI, depois de atualizar: marcar SEG_PERIODO como tabela de datas
--   usando PERI_DT_REFERENCIA e ordenar PERI_NM_MES por PERI_NR_MES
--   (ver powerbi/README.md).
--
-- ORDEM  : executar depois de 02_CARGA.sql (ver sql/RUNBOOK.md)
-- ROLLBACK:
--   ALTER TABLE SEG_PERIODO
--     DROP COLUMN PERI_DT_REFERENCIA,
--     DROP COLUMN PERI_NM_MES,
--     DROP COLUMN PERI_NR_TRIMESTRE;
-- ==========================================================================

USE seg_dashboard;

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-007
-- comment: Adicionando colunas de data em SEG_PERIODO
-- --------------------------------------------------------------------------
ALTER TABLE SEG_PERIODO
	ADD COLUMN IF NOT EXISTS PERI_DT_REFERENCIA DATE        NULL AFTER PERI_NR_ANO,
	ADD COLUMN IF NOT EXISTS PERI_NM_MES        VARCHAR(20) NULL AFTER PERI_DT_REFERENCIA,
	ADD COLUMN IF NOT EXISTS PERI_NR_TRIMESTRE  TINYINT     NULL AFTER PERI_NM_MES;

-- comment on column SEG_PERIODO.PERI_DT_REFERENCIA is 'Primeiro dia do mes de referencia, usado como chave de data no Power BI';
-- comment on column SEG_PERIODO.PERI_NM_MES is 'Nome abreviado do mes para exibicao (jan, fev, ...)';
-- comment on column SEG_PERIODO.PERI_NR_TRIMESTRE is 'Trimestre do ano (1 a 4)';

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-008
-- comment: Preenchendo as colunas de data a partir de mes e ano
-- obs: derivado, nunca digitado - vale para qualquer ano que a base receba
-- --------------------------------------------------------------------------
UPDATE SEG_PERIODO
SET PERI_DT_REFERENCIA = MAKEDATE(PERI_NR_ANO, 1) + INTERVAL (PERI_NR_MES - 1) MONTH,
	PERI_NR_TRIMESTRE  = QUARTER(MAKEDATE(PERI_NR_ANO, 1) + INTERVAL (PERI_NR_MES - 1) MONTH),
	PERI_NM_MES        = ELT(PERI_NR_MES,
		'jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez');

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-009
-- comment: Tornando PERI_DT_REFERENCIA obrigatoria e unica
-- obs: uma tabela de datas do Power BI nao aceita data nula nem repetida
-- --------------------------------------------------------------------------
ALTER TABLE SEG_PERIODO
	MODIFY COLUMN PERI_DT_REFERENCIA DATE        NOT NULL,
	MODIFY COLUMN PERI_NM_MES        VARCHAR(20) NOT NULL,
	MODIFY COLUMN PERI_NR_TRIMESTRE  TINYINT     NOT NULL;

ALTER TABLE SEG_PERIODO
	ADD CONSTRAINT IF NOT EXISTS PERI_UK_02 UNIQUE (PERI_DT_REFERENCIA);
