# Plano da Dashboard A3 — Criminalidade RJ 2025

> Documento de referência do grupo: objetivo, público, KPIs, páginas, identidade visual e inspirações.
> O estado de implementação de cada item está no final, em [Próximos passos](#próximos-passos).
> Detalhe técnico do banco: [MODELO_DE_DADOS.md](MODELO_DE_DADOS.md) · Montagem do relatório: [`powerbi/README.md`](../powerbi/README.md)

A dashboard deve ser um relatório Power BI de 4 páginas sobre as 137 delegacias do RJ em 2025, com letalidade violenta, roubos e furtos como KPIs principais. Antes dos gráficos, é preciso corrigir 3 pontos do modelo que hoje inflam os totais.

## O que o repositório entrega

O repo não tem código de dashboard ainda: traz um banco MySQL (XAMPP) já normalizado, uma planilha explicada e um guia de conexão com o Power BI. Os dados são da base pública do ISP-RJ (`BaseDPEvolucaoMensalCisp.csv`), filtrada para jan–dez de 2025, com códigos IBGE dos municípios.

| Arquivo | O que é |
| --- | --- |
| `sql/01_TABELAS.sql` | Cria o banco `seg_dashboard` com 11 tabelas, PKs, FKs e índices |
| `sql/02_CARGA.sql` | Insere 85.986 linhas de 2025 |
| `dados/PLANILHA EXPLICADA.xlsx` | Uma aba por tabela + aba INDICE explicando colunas |
| `docs/GUIA_DE_ACESSO.pdf` | Passo a passo XAMPP → Power BI, relacionamentos e 4 medidas DAX iniciais |

**Modelo (estrela com hierarquias):** o fato principal é `SEG_OCORRENCIA_MENSAL` (83.844 linhas = 137 delegacias × 12 meses × 51 tipos). Ele se liga a `SEG_REGISTRO_MENSAL` (delegacia × mês, com total de BOs) e daí às dimensões:

- **Território policial:** RISP (7) → AISP (40, batalhão da PM) → CISP (137, delegacia)
- **Território civil:** Região (4) → Município (92), ligado à delegacia por `SEG_CISP_MUNICIPIO` (muitos-para-muitos)
- **Crime:** Categoria (8) → Tipo de ocorrência (51 indicadores do ISP)
- **Tempo:** Período (12 meses de 2025)

**Números de 2025 conferidos rodando a carga:**

| Indicador | Total 2025 |
| --- | --- |
| Boletins de ocorrência (BOs) | 965.208 |
| Letalidade violenta | 3.892 |
| Homicídio doloso | 2.844 |
| Morte por intervenção de agente do Estado | 800 |
| Feminicídio | 105 |
| Estupro | 5.867 |
| Total de roubos (categoria) | 98.459 |
| Roubo de celular | 25.581 |
| Roubo de veículo | 25.235 |
| Total de furtos | 187.984 |
| Estelionato | 146.981 |

A Baixada Fluminense lidera a letalidade violenta por RISP (1.055 mortes), seguida da Zona Oeste/parte da Zona Norte da capital (994). As delegacias com mais mortes são a 22ª, 54ª e 64ª DP (155, 148 e 146).

## Armadilhas nos dados (corrigir antes dos gráficos)

Três pontos fazem a dashboard mostrar números errados se forem usados como estão no guia.

| Problema | Efeito | Correção |
| --- | --- | --- |
| Tipos que são **totais** de outros tipos: `letalidade_violenta` (soma de homicídio, latrocínio, lesão seguida de morte, MDIP e feminicídio) e `total_furtos` (soma dos furtos) | A medida `Total Ocorrências` (946.380) conta esses crimes duas vezes. A categoria Furtos dá 376.530, o dobro do real (187.984). A categoria Letalidade dá 7.803 em vez de 3.892 | Criar a coluna `TIOC_FL_AGREGADO` (S/N) em `SEG_TIPO_OCORRENCIA` e filtrar `N` nas somas. Usar os agregados só nos KPIs próprios. Verificar também `apreensao_drogas` (25.830), que parece somar posse, tráfico e sem autor |
| A medida `CVLI` do guia não inclui `feminicidio` | Nesta base o homicídio doloso não inclui feminicídio (2.844 + 66 + 77 + 800 + 105 = 3.892). O CVLI do guia (2.987) perde 105 mortes | Somar `feminicidio` ao CVLI (fica 3.092) |
| Delegacia que atende mais de um município (9 delegacias do Interior, ex.: 108ª DP em Três Rios, Areal e Levy Gasparian) + filtro cruzado "Ambas" | Somar por município ou região repete a ocorrência em cada município: a letalidade por região soma 4.075, 183 a mais que o real | Para mapas e rankings usar delegacia (CISP), AISP ou RISP. Para região, marcar um município-sede por delegacia e filtrar só por ele |

Também vale saber: a categoria "Atividade policial" (prisões em flagrante, mandados, recuperação de veículos) mede produtividade da polícia, não crime, e não deve entrar em totais de criminalidade. Não há população no banco, então taxas por 100 mil habitantes exigem adicionar a população do IBGE (Censo 2022 ou estimativa 2025) em `SEG_MUNICIPIO`.

## Objetivo, público e perguntas

Objetivo: mostrar onde, quando e quais crimes aconteceram no RJ em 2025, de forma que um leigo entenda em 10 segundos e um analista consiga descer até a delegacia.

Público principal: banca e professores do A3, seguidos de quem acompanha segurança pública (gestores, jornalistas, cidadãos). Isso pede leitura rápida, números grandes e poucos filtros.

Perguntas que a dashboard responde:

1. Quantas mortes violentas houve em 2025 e quais meses foram piores?
2. Quais regiões, batalhões (AISP) e delegacias concentram letalidade, roubos e furtos?
3. Qual é o perfil de crime de cada região (mais patrimonial ou mais violento)?
4. Quais crimes contra a mulher e contra a pessoa se destacam?
5. Quanto da letalidade vem de intervenção policial, e como está a atividade policial (prisões, apreensões)?

## KPIs e medidas DAX

Seis KPIs no topo da página principal, cada um com o valor do ano e a variação do último mês filtrado contra o mês anterior. Todos usam os tipos individuais, nunca os agregados, exceto quando o próprio KPI é o agregado.

| KPI | Definição | Valor 2025 |
| --- | --- | --- |
| Letalidade violenta | Tipo `letalidade_violenta` | 3.892 |
| Mortes por intervenção do Estado | Tipo `hom_por_interv_policial` (e % da letalidade) | 800 (20,6%) |
| Roubos | Categoria Roubos | 98.459 |
| Furtos | Tipo `total_furtos` | 187.984 |
| Estelionato | Tipo `estelionato` | 146.981 |
| Total de BOs | `REME_QT_REGISTRO_OCORRENCIAS` | 965.208 |

As medidas que substituem as do guia estão implementadas e comentadas em [`powerbi/dax/`](../powerbi/dax/), divididas por camada:

| Arquivo | Conteúdo |
| --- | --- |
| `00_base.dax` | `[Ocorrências]` (a base de todo somatório), `[Atividade policial]`, `[Total de BOs]` |
| `10_kpis.dax` | Os 6 KPIs, `[CVLI]` corrigido, crimes contra a mulher, produção da polícia |
| `20_tempo.dax` | Mês anterior e variação % de cada KPI |
| `30_territorio.dax` | Medidas `(por sede)`, ranking de delegacias, `[% Crime patrimonial]` |
| `40_taxas.dax` | Taxas por 100 mil e comparação com a média do estado |

Duas decisões que valem registro, por divergirem do que o guia sugeria:

- **`KEEPFILTERS` na medida base.** Um argumento de filtro do `CALCULATE` *substitui* o filtro que o usuário colocou naquela coluna. Sem `KEEPFILTERS`, o segmentador de categoria pararia de funcionar: escolher "Roubos" devolveria todas as categorias menos "Atividade policial".
- **`SEG_PERIODO` como tabela de datas, em vez de uma `dCalendario`.** O fato já é mensal e já se liga a essa tabela; uma tabela de calendário paralela acrescentaria um relacionamento e um risco de granularidade divergente sem resolver nada.

## Páginas e layout

Quatro páginas em 16:9 (1280×720), todas com o mesmo cabeçalho e a mesma faixa de filtros, para quem navega não se perder.

| Página | Pergunta que responde | Conteúdo |
| --- | --- | --- |
| 1. Visão geral | Como foi 2025? | 6 cartões de KPI, linha mensal da letalidade, mapa por município/RISP, barras por categoria, top 10 delegacias |
| 2. Território | Onde acontece? | Mapa coroplético, matriz RISP → AISP → delegacia com totais, heatmap delegacia × mês, ranking com drill-down |
| 3. Tipos de crime | O que acontece? | Árvore categoria → tipo, barras dos 15 maiores tipos, small multiples mensais de roubos, furtos e estelionato, painel de crimes contra a mulher (estupro, feminicídio, tentativa) |
| 4. Letalidade e atividade policial | Quem morre e o que a polícia faz? | Composição da letalidade (homicídio, MDIP, latrocínio...), MDIP por RISP, prisões em flagrante, mandados e apreensões por mês |

Filtros fixos (faixa superior, sincronizados entre páginas): mês, região, RISP, AISP e categoria. Página extra opcional: uma tooltip page que mostra, ao passar o mouse sobre uma delegacia, os bairros atendidos (`CISP_DS_UNIDADE_TERRITORIAL`) e seus 5 maiores crimes.

## Wireframe da página principal

```
+--------------------------------------------------------------------------+
| Criminalidade no RJ — 2025   Fonte: ISP-RJ   Visão geral·Território·Tipos·Letalidade |
+--------------------------------------------------------------------------+
| Filtros: Mês · Região · RISP · AISP · Categoria · Limpar filtros          |
+--------------------------------------------------------------------------+
| [LETALIDADE] | Interv. Estado | Roubos  | Furtos   | Estelionato | Total de BOs |
|   3.892      |     800        | 98.459  | 187.984  |  146.981    |   965.208    |
+------------------------------------------+-------------------------------+
| Letalidade violenta por mês              | Mapa do estado                |
| Gráfico de linhas, jan–dez 2025          | Shape map por município-sede  |
| Pico anotado: outubro, 431 mortes        | Cor sequencial em 5 faixas    |
| Linha secundária opcional: roubos        | Clique filtra a página        |
+------------------------------------+-------------------------------------+
| Ocorrências por categoria          | Top 10 delegacias                   |
| Barras horizontais, sem agregados  | Barras horizontais ordenadas        |
| e sem atividade policial           | Tooltip com bairros atendidos       |
+------------------------------------+-------------------------------------+
Rodapé: CISP = delegacia · AISP = batalhão da PM · RISP = região integrada · dados de jan a dez de 2025
```

A leitura segue em Z: o cartão de letalidade é o único destacado, a tendência e o mapa explicam quando e onde, e os rankings embaixo apontam quem puxa os números.

## Gráfico certo para cada pergunta

| Pergunta | Visual Power BI | Por quê | Evitar |
| --- | --- | --- | --- |
| Evolução mensal | Gráfico de linhas com marcador no pico (outubro: 431 mortes) | Tendência em 12 pontos se lê melhor em linha | Colunas 3D, eixo Y sem começar em zero em barras |
| Ranking de delegacias/AISPs | Barras horizontais ordenadas, top 10 | Nomes longos cabem e a ordem salta aos olhos | Pizza com 137 fatias |
| Distribuição no território | Mapa de formas (Shape map) por município, cor sequencial | Mostra concentração geográfica | Mapa de bolhas sobrepostas na capital |
| Composição (letalidade, categorias) | Barra 100% empilhada ou treemap | Partes de um todo com poucos itens | Pizza com mais de 5 fatias |
| Padrão delegacia × mês | Matriz com formatação condicional (heatmap) | Vê meses atípicos de cada delegacia de uma vez | Tabela crua sem cor |
| Hierarquia RISP → AISP → CISP | Árvore de decomposição ou matriz com drill-down | Explora a hierarquia que o modelo já tem | Três gráficos separados |
| Vários crimes no tempo | Small multiples (linhas pequenas com mesma escala) | Compara ritmo sem misturar escalas | Uma linha com 10 séries |
| Valor de destaque | Cartão (novo Card visual) com variação e sparkline | Leitura em 1 segundo | Gauge/velocímetro sem meta |

Para o mapa, o Shape map aceita um TopoJSON customizado. A malha dos municípios do RJ sai da API de malhas do IBGE (estado 33, divisão por município) e pode ser convertida para TopoJSON no mapshaper.org — passo a passo em [`powerbi/README.md`](../powerbi/README.md). A chave de ligação é `MUNI_CD_IBGE`. Pela armadilha do muitos-para-muitos, o mapa deve somar por município-sede da delegacia.

## Identidade visual, componentes e interações

Direção: sóbria e institucional, fundo claro e uma única cor de alerta. O tema é sensível (mortes), então nada de cores festivas, ícones de caveira ou vermelho em tudo.

| Elemento | Escolha |
| --- | --- |
| Fundo | Cinza muito claro `#F5F6F8`, cartões brancos com cantos de 8 px e sombra leve |
| Cor principal | Azul petróleo `#1F4E79` (títulos, barras padrão) |
| Cor de alerta | Vermelho tijolo `#C0392B`, só para letalidade e destaques |
| Escala do mapa | Sequencial de um tom (claro → `#1F4E79`), 5 faixas |
| Categorias | Até 6 cores fixas por categoria, iguais em todas as páginas |
| Fonte | Segoe UI (padrão do Power BI): KPI 28–32 pt, títulos 14 pt, rótulos 10 pt |
| Grade | Margem de 16 px, espaço de 12 px entre visuais, tudo alinhado em 4 colunas |

Tudo isso está codificado em [`powerbi/tema/tema-a3-criminalidade-rj.json`](../powerbi/tema/tema-a3-criminalidade-rj.json), para o grupo inteiro usar o mesmo tema. Mudança de cor ou fonte se faz no JSON e recarregando o tema, nunca no painel de formatação de um visual — formatação local sobrescreve o tema e sai do controle de versão.

Componentes reutilizáveis: cabeçalho com título, fonte ("ISP-RJ, 2025") e data de atualização; faixa de filtros; cartão de KPI (valor, variação com seta, sparkline); botões de navegação entre páginas; botão "Limpar filtros" (bookmark); nota de rodapé explicando o que é CISP, AISP e RISP.

Interações: clique em qualquer barra filtra a página; drill-down RISP → AISP → delegacia; tooltip page com bairros da delegacia; filtros sincronizados entre páginas.

## Fontes de inspiração

Os melhores modelos vêm de painéis reais de segurança pública e da galeria do Power BI, porque usam o mesmo tipo de dado e a mesma ferramenta. Dribbble e Behance servem para acabamento visual (cartões, cores, espaçamento).

| Fonte | Tipo | O que copiar |
| --- | --- | --- |
| [ISP Dados RJ](https://www.ispdados.rj.gov.br) | Painel oficial, mesma base | Nomes dos indicadores, notas metodológicas, recorte por RISP/AISP/CISP |
| [ISP lança ferramenta de indicadores por município (Tupi)](https://www.tupi.fm/?p=896069) | Notícia sobre painel do ISP | Visão municipal e comparativos |
| [Séries históricas de letalidade violenta (ISP)](https://www.rj.gov.br/isp/sites/default/files/2022-05/SeriesHistoricasLetalidadeViolenta.pdf) | Relatório oficial | Composição da letalidade e gráficos de série |
| [Painel de violência contra a mulher no RJ (Brasil de Fato)](https://www.brasildefato.com.br/2024/03/08/painel-interativo-mostra-dados-sobre-violencia-contra-mulher-no-rj/) | Painel interativo | Seção dedicada a crimes contra a mulher |
| [Anuário Brasileiro de Segurança Pública 2025 (FBSP)](https://forumseguranca.org.br/publicacoes/anuario-brasileiro-de-seguranca-publica-2025/) | Publicação nacional | Taxas por 100 mil, comparativos entre estados, tom editorial |
| [Washington DC Crimes Analysis 2025 (ZoomCharts)](https://zoomcharts.com/en/microsoft-power-bi-custom-visuals/dashboard-and-report-examples/view/washington-dc-crimes-analysis-2025) | Relatório Power BI | Layout de KPIs + mapa + drill-down interativo |
| [Tactical Crime Analysis (ZoomCharts)](https://zoomcharts.com/en/microsoft-power-bi-custom-visuals/dashboard-and-report-examples/view/tactical-crime-analysis-23) | Relatório Power BI | Heatmap por período e filtros cruzados |
| [Crime Overview — Los Angeles 2020–2024 (Data Stories Gallery)](https://community.fabric.microsoft.com/t5/Data-Stories-Gallery/Crime-Overview-City-of-Los-Angeles-2020-2024/m-p/5124209) | Galeria oficial Power BI | Estrutura de páginas e storytelling |
| [UK Public Sector — Police Services (Data Stories Gallery)](https://community.fabric.microsoft.com/t5/Data-Stories-Gallery/UK-Public-Sector-Police-Services/m-p/120360) | Galeria oficial Power BI | Painel institucional por área policial |
| [Chicago Crime (Yellowfin)](https://yellowfinbi.com/analytics-best-practice/dashboard-gallery/chicago-crime) | Galeria de BI | Mapa + ranking + tendência em uma tela |
| [London Crime Rates Dashboard Design (Contra)](https://contra.com/p/RQZFFvlU-london-crime-rates-dashboard-design) | Design de UI | Cartões de KPI e paleta sóbria |
| [Dribbble: busca "crime dashboard"](https://dribbble.com/search/crime-dashboard) | Galeria de design | Acabamento de cartões, sparklines, modo claro |
| [Behance: busca "crime dashboard"](https://www.behance.net/search/projects?search=crime%20dashboard) | Galeria de design | Estudos de caso completos de dashboards |
| [Microsoft Learn: design de layout de relatórios](https://learn.microsoft.com/en-us/training/modules/power-bi-effective-reports/2-design-layout) | Guia oficial | Hierarquia visual, grade e ordem de leitura |
| [Microsoft Learn: dicas de design de dashboards](https://learn.microsoft.com/en-gb/power-BI/create-reports/service-dashboards-design-tips) | Guia oficial | O que colocar no topo, quantos visuais por tela |

Os links de Dribbble e Behance são páginas de busca; vale salvar 5 a 8 telas favoritas num moodboard do grupo (Figma ou Miro) antes de montar o tema.

## Próximos passos

Feito no repositório:

- [x] Adicionar `TIOC_FL_AGREGADO` em `SEG_TIPO_OCORRENCIA` e marcar `letalidade_violenta` e `total_furtos` como agregados — `apreensao_drogas` é marcada só se o próprio dado confirmar a soma
- [x] Marcar um município-sede por delegacia em `SEG_CISP_MUNICIPIO` (coluna `CIMU_FL_SEDE`)
- [x] Criar a dimensão de tempo (`PERI_DT_REFERENCIA` em `SEG_PERIODO`) para as medidas de variação mensal
- [x] Trocar as medidas DAX do guia pelas do plano, com os valores de 2025 conferidos em `sql/qa/`
- [x] Fechar o tema JSON (cores e fontes)
- [x] Preparar as colunas de população (`MUNI_QT_POPULACAO`, `MUNI_AA_POPULACAO`) e o script que gera o seed do IBGE

Falta fazer — depende de rodar o banco ou do Power BI Desktop:

- [ ] Rodar `scripts/gerar_populacao_ibge.py` e aplicar o seed de população
- [ ] Rodar o QA (`sql/qa/`) e confirmar que todos os testes dão `OK`
- [ ] Baixar a malha do RJ no IBGE e gerar o TopoJSON do mapa
- [ ] Montar o moodboard com 5 a 8 referências
- [ ] Construir a página 1 (Visão geral) e validar com o grupo antes das outras 3
- [ ] Construir as páginas 2 a 4, a tooltip page e os botões de navegação
- [ ] Escrever a nota metodológica (fonte, período, o que é cada indicador) no rodapé ou numa página "Sobre"
