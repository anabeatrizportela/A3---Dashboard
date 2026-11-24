-- ==========================================================================
-- PROJETO : A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)
-- SGBD    : MySQL / MariaDB (XAMPP)
-- ARQUIVO : 03_02_CISP_MUNICIPIO_SEDE.sql
-- ASSUNTO : Armadilha 3 - delegacia que atende mais de um municipio
--
-- PROBLEMA
--   SEG_CISP_MUNICIPIO e muitos-para-muitos: 9 das 137 delegacias atendem
--   mais de um municipio (147 ligacoes para 137 delegacias). Somar ocorrencias
--   por municipio ou por regiao repete a MESMA ocorrencia em cada municipio
--   atendido: a letalidade por regiao soma 4.075 em vez de 3.892 (+183).
--
-- SOLUCAO
--   Marcar UM municipio-sede por delegacia (CIMU_FL_SEDE = 'S') e usar esse
--   filtro em mapas, rankings por municipio e qualquer soma por regiao.
--   A ligacao completa continua disponivel para responder "quais municipios
--   esta delegacia atende".
--
-- ORDEM  : executar depois de 02_CARGA.sql (ver sql/RUNBOOK.md)
-- ROLLBACK:
--   ALTER TABLE SEG_CISP_MUNICIPIO DROP COLUMN CIMU_FL_SEDE;
-- ==========================================================================

USE seg_dashboard;

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-004
-- comment: Adicionando coluna CIMU_FL_SEDE em SEG_CISP_MUNICIPIO
-- --------------------------------------------------------------------------
ALTER TABLE SEG_CISP_MUNICIPIO
	ADD COLUMN IF NOT EXISTS CIMU_FL_SEDE CHAR(1) NOT NULL DEFAULT 'N'
		AFTER MUNI_ID_MUNICIPIO;

-- comment on column SEG_CISP_MUNICIPIO.CIMU_FL_SEDE is 'Indica o municipio onde a delegacia esta instalada, usado para somar sem duplicar (S - Sede/N - Apenas atendido)';

ALTER TABLE SEG_CISP_MUNICIPIO
	ADD CONSTRAINT IF NOT EXISTS CIMU_CK_01 CHECK (CIMU_FL_SEDE IN ('S','N'));

CREATE INDEX IF NOT EXISTS CIMU_IX_03 ON SEG_CISP_MUNICIPIO (CIMU_FL_SEDE);

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-005
-- comment: Delegacia de municipio unico - a sede e a propria (derivado do dado)
-- obs: cobre 128 das 137 delegacias sem nenhuma decisao manual. O JOIN com a
--      tabela derivada evita o erro 1093 do MySQL.
-- --------------------------------------------------------------------------
UPDATE SEG_CISP_MUNICIPIO CM
JOIN (
	SELECT CISP_ID_CISP
	FROM SEG_CISP_MUNICIPIO
	GROUP BY CISP_ID_CISP
	HAVING COUNT(*) = 1
) UNICO ON UNICO.CISP_ID_CISP = CM.CISP_ID_CISP
SET CM.CIMU_FL_SEDE = 'S';

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-006
-- comment: Delegacia multi-municipio - sede explicita (9 casos, todos no Interior)
-- obs: criterio = municipio onde a delegacia esta instalada, nao o primeiro
--      nome de CISP_DS_UNIDADE_TERRITORIAL (que nao segue essa ordem: a 108a
--      fica em Tres Rios e a descricao comeca por Areal). As 9 linhas abaixo
--      sao as UNICAS decisoes manuais do modelo; qualquer revisao mexe so aqui.
--      A consulta sql/qa/qa_02_integridade_modelo.sql garante uma sede por CISP.
-- --------------------------------------------------------------------------
INSERT INTO SEG_CISP_MUNICIPIO (CISP_ID_CISP, MUNI_ID_MUNICIPIO, CIMU_FL_SEDE)
SELECT SEDE.CISP_ID_CISP, SEDE.MUNI_ID_MUNICIPIO, 'S'
FROM (
	--  CISP  MUNI   delegacia   sede                          tambem atende
	SELECT  81 AS CISP_ID_CISP, 44 AS MUNI_ID_MUNICIPIO UNION ALL -- 96a DP  Miguel Pereira            / Paty do Alferes
	SELECT  85, 59 UNION ALL -- 100a DP  Porto Real                / Quatis
	SELECT  91, 88 UNION ALL -- 108a DP  Tres Rios                 / Areal, Com. Levy Gasparian
	SELECT 108, 62 UNION ALL -- 130a DP  Quissama                  / Carapebus
	SELECT 112, 70 UNION ALL -- 136a DP  Santo Antonio de Padua    / Aperibe
	SELECT 116, 46 UNION ALL -- 140a DP  Natividade                / Varre-Sai
	SELECT 119, 33 UNION ALL -- 143a DP  Itaperuna                 / Sao Jose de Uba
	SELECT 124, 18 UNION ALL -- 148a DP  Italva                    / Cardoso Moreira
	SELECT 128, 23           -- 154a DP  Cordeiro                  / Macuco
) SEDE
ON DUPLICATE KEY UPDATE CIMU_FL_SEDE = 'S';

-- As ligacoes ja existiam na carga, entao o INSERT cai sempre no
-- ON DUPLICATE KEY (CIMU_UK_01) e apenas marca a sede. O formato de INSERT
-- foi escolhido para manter a lista de decisoes em um unico bloco legivel.
