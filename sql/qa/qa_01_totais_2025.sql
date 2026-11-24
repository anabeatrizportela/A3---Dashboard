-- ==========================================================================
-- PROJETO : A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)
-- ARQUIVO : qa_01_totais_2025.sql
-- ASSUNTO : Conferencia dos totais de 2025 - "teste automatizado" do modelo
--
-- COMO USAR
--   Rodar depois das migracoes 03_*. Cada consulta devolve uma coluna
--   DS_RESULTADO com OK ou FALHOU. Se qualquer linha vier FALHOU, as medidas
--   DAX de powerbi/dax/ vao mostrar numero errado - corrigir o banco antes de
--   montar visual nenhum.
--
--   Os valores esperados sao os do plano (docs/PLANO_DASHBOARD.md), apurados
--   sobre a base do ISP de jan a dez de 2025.
-- ==========================================================================

USE seg_dashboard;

-- --------------------------------------------------------------------------
-- QA 1.1 - Totais por indicador
-- --------------------------------------------------------------------------
SELECT
	'1.1 Totais por indicador'						AS DS_TESTE,
	T.TIOC_CD_TIPO_OCORRENCIA						AS CD_TIPO,
	ESPERADO.QT_ESPERADO							AS QT_ESPERADO,
	SUM(O.OCME_QT_OCORRENCIA)						AS QT_APURADO,
	CASE WHEN SUM(O.OCME_QT_OCORRENCIA) = ESPERADO.QT_ESPERADO
		THEN 'OK' ELSE 'FALHOU' END					AS DS_RESULTADO
FROM SEG_OCORRENCIA_MENSAL O
JOIN SEG_TIPO_OCORRENCIA T ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
JOIN (
	SELECT 'letalidade_violenta'     AS CD_TIPO,   3892 AS QT_ESPERADO UNION ALL
	SELECT 'hom_doloso',                           2844 UNION ALL
	SELECT 'hom_por_interv_policial',               800 UNION ALL
	SELECT 'feminicidio',                           105 UNION ALL
	SELECT 'estupro',                              5867 UNION ALL
	SELECT 'roubo_celular',                       25581 UNION ALL
	SELECT 'roubo_veiculo',                       25235 UNION ALL
	SELECT 'total_furtos',                       187984 UNION ALL
	SELECT 'estelionato',                        146981
) ESPERADO ON ESPERADO.CD_TIPO = T.TIOC_CD_TIPO_OCORRENCIA
GROUP BY T.TIOC_CD_TIPO_OCORRENCIA, ESPERADO.QT_ESPERADO
ORDER BY T.TIOC_CD_TIPO_OCORRENCIA;

-- --------------------------------------------------------------------------
-- QA 1.2 - Total de BOs (fato de granularidade delegacia x mes)
-- --------------------------------------------------------------------------
SELECT
	'1.2 Total de BOs'								AS DS_TESTE,
	965208											AS QT_ESPERADO,
	SUM(REME_QT_REGISTRO_OCORRENCIAS)				AS QT_APURADO,
	CASE WHEN SUM(REME_QT_REGISTRO_OCORRENCIAS) = 965208
		THEN 'OK' ELSE 'FALHOU' END					AS DS_RESULTADO
FROM SEG_REGISTRO_MENSAL;

-- --------------------------------------------------------------------------
-- QA 1.3 - Armadilha 1: categoria SEM agregados bate com o total real
-- Furtos deve dar 187.984 (e nao 376.530) e Letalidade 3.892 (e nao 7.803)
-- --------------------------------------------------------------------------
SELECT
	'1.3 Categoria sem agregados'					AS DS_TESTE,
	C.CAOC_NM_CATEGORIA								AS NM_CATEGORIA,
	ESPERADO.QT_ESPERADO							AS QT_ESPERADO,
	SUM(O.OCME_QT_OCORRENCIA)						AS QT_APURADO,
	CASE WHEN SUM(O.OCME_QT_OCORRENCIA) = ESPERADO.QT_ESPERADO
		THEN 'OK' ELSE 'FALHOU' END					AS DS_RESULTADO
FROM SEG_OCORRENCIA_MENSAL O
JOIN SEG_TIPO_OCORRENCIA       T ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
JOIN SEG_CATEGORIA_OCORRENCIA  C ON C.CAOC_ID_CATEGORIA_OCORRENCIA = T.CAOC_ID_CATEGORIA_OCORRENCIA
JOIN (
	SELECT 'Furtos'              AS NM_CATEGORIA, 187984 AS QT_ESPERADO UNION ALL
	SELECT 'Letalidade violenta',                   3892 UNION ALL
	SELECT 'Roubos',                               98459
) ESPERADO ON ESPERADO.NM_CATEGORIA = C.CAOC_NM_CATEGORIA
WHERE T.TIOC_FL_AGREGADO = 'N'
GROUP BY C.CAOC_NM_CATEGORIA, ESPERADO.QT_ESPERADO
ORDER BY C.CAOC_NM_CATEGORIA;

-- --------------------------------------------------------------------------
-- QA 1.4 - Armadilha 2: CVLI com feminicidio
-- O guia original devolve 2.987 porque esquece feminicidio; o correto e 3.092
-- --------------------------------------------------------------------------
SELECT
	'1.4 CVLI com feminicidio'						AS DS_TESTE,
	3092											AS QT_ESPERADO,
	SUM(O.OCME_QT_OCORRENCIA)						AS QT_APURADO,
	CASE WHEN SUM(O.OCME_QT_OCORRENCIA) = 3092
		THEN 'OK' ELSE 'FALHOU' END					AS DS_RESULTADO
FROM SEG_OCORRENCIA_MENSAL O
JOIN SEG_TIPO_OCORRENCIA T ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
WHERE T.TIOC_CD_TIPO_OCORRENCIA IN ('hom_doloso', 'lesao_corp_morte', 'latrocinio', 'feminicidio');

-- --------------------------------------------------------------------------
-- QA 1.5 - Armadilha 1 (fechamento): letalidade_violenta = soma dos 5 tipos
-- Prova que o agregado nao e um indicador independente
-- --------------------------------------------------------------------------
SET @qt_agregado = (
	SELECT SUM(O.OCME_QT_OCORRENCIA)
	FROM SEG_OCORRENCIA_MENSAL O
	JOIN SEG_TIPO_OCORRENCIA T ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
	WHERE T.TIOC_CD_TIPO_OCORRENCIA = 'letalidade_violenta'
);
SET @qt_partes = (
	SELECT SUM(O.OCME_QT_OCORRENCIA)
	FROM SEG_OCORRENCIA_MENSAL O
	JOIN SEG_TIPO_OCORRENCIA T ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
	WHERE T.TIOC_CD_TIPO_OCORRENCIA IN
		('hom_doloso', 'lesao_corp_morte', 'latrocinio', 'hom_por_interv_policial', 'feminicidio')
);
SELECT
	'1.5 Agregado = soma das partes'				AS DS_TESTE,
	@qt_agregado									AS QT_AGREGADO,
	@qt_partes										AS QT_SOMA_PARTES,
	CASE WHEN @qt_agregado = @qt_partes
		THEN 'OK' ELSE 'FALHOU' END					AS DS_RESULTADO;

-- --------------------------------------------------------------------------
-- QA 1.6 - Armadilha 3: letalidade por regiao com e sem filtro de sede
-- Sem sede soma 4.075 (183 a mais); com sede tem de fechar em 3.892
-- --------------------------------------------------------------------------
SELECT
	'1.6 Letalidade por regiao'						AS DS_TESTE,
	SUM(CASE WHEN CM.CIMU_FL_SEDE = 'S'
		THEN O.OCME_QT_OCORRENCIA ELSE 0 END)		AS QT_COM_FILTRO_SEDE,
	SUM(O.OCME_QT_OCORRENCIA)						AS QT_SEM_FILTRO_SEDE,
	CASE WHEN SUM(CASE WHEN CM.CIMU_FL_SEDE = 'S'
			THEN O.OCME_QT_OCORRENCIA ELSE 0 END) = 3892
		THEN 'OK' ELSE 'FALHOU' END					AS DS_RESULTADO
FROM SEG_OCORRENCIA_MENSAL O
JOIN SEG_TIPO_OCORRENCIA   T  ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
JOIN SEG_REGISTRO_MENSAL   R  ON R.REME_ID_REGISTRO_MENSAL = O.REME_ID_REGISTRO_MENSAL
JOIN SEG_CISP_MUNICIPIO    CM ON CM.CISP_ID_CISP = R.CISP_ID_CISP
WHERE T.TIOC_CD_TIPO_OCORRENCIA = 'letalidade_violenta';

-- --------------------------------------------------------------------------
-- QA 1.7 - Pico mensal da letalidade (anotacao do grafico de linhas)
-- O plano aponta outubro com 431 mortes
-- --------------------------------------------------------------------------
SELECT
	'1.7 Letalidade por mes'						AS DS_TESTE,
	P.PERI_NR_MES									AS NR_MES,
	P.PERI_NM_MES									AS NM_MES,
	SUM(O.OCME_QT_OCORRENCIA)						AS QT_LETALIDADE
FROM SEG_OCORRENCIA_MENSAL O
JOIN SEG_TIPO_OCORRENCIA T ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
JOIN SEG_REGISTRO_MENSAL R ON R.REME_ID_REGISTRO_MENSAL = O.REME_ID_REGISTRO_MENSAL
JOIN SEG_PERIODO         P ON P.PERI_ID_PERIODO = R.PERI_ID_PERIODO
WHERE T.TIOC_CD_TIPO_OCORRENCIA = 'letalidade_violenta'
GROUP BY P.PERI_NR_MES, P.PERI_NM_MES
ORDER BY QT_LETALIDADE DESC;
