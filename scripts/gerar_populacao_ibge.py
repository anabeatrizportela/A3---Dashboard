#!/usr/bin/env python3
"""Gera o seed de populacao dos municipios do RJ a partir da API do IBGE.

Projeto: A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)

POR QUE ESTE SCRIPT EXISTE
    A dashboard precisa de taxas por 100 mil habitantes, e o banco do ISP nao
    traz populacao. Digitar 92 numeros a mao e a maneira mais facil de colocar
    um erro invisivel no trabalho: ninguem confere 92 numeros. Aqui a
    populacao vem da fonte oficial, o SQL e gerado, e o ano de referencia vai
    junto para a nota metodologica.

O QUE ELE FAZ
    1. Le a API de agregados do IBGE (SIDRA) para a populacao dos municipios
       do estado 33 (Rio de Janeiro).
    2. Escreve sql/seed/04_POPULACAO_IBGE.sql com um UPDATE por municipio,
       casado por MUNI_CD_IBGE (que ja esta na carga).
    3. Reclama em pe se a API devolver menos municipios do que o esperado, em
       vez de gerar um seed pela metade em silencio.

COMO USAR
    python3 -I scripts/gerar_populacao_ibge.py
    python3 -I scripts/gerar_populacao_ibge.py --agregado 4714 --variavel 93
    (depois, aplicar o arquivo gerado - ver sql/RUNBOOK.md)

FONTES (agregados do SIDRA/IBGE)
    4714 / variavel 93  Censo 2022 - populacao residente        <- padrao
    6579 / variavel 9324  Estimativas da populacao por ano

    O agregado 4714 e o padrao porque o Censo 2022 e dado apurado, nao
    estimativa, e porque o periodo e unico (2022) - nao muda de um semestre
    para o outro no meio do trabalho do grupo.

DEPENDENCIAS
    Nenhuma alem da biblioteca padrao do Python 3.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuracao
# ---------------------------------------------------------------------------

URL_API = (
    "https://servicodados.ibge.gov.br/api/v3/agregados/{agregado}"
    "/periodos/{periodo}/variaveis/{variavel}"
    "?localidades=N6[N3[33]]"
)

#: Codigo do estado do Rio de Janeiro na malha do IBGE.
UF_RIO_DE_JANEIRO = 33

#: Municipios do RJ. A base do ISP cobre 92 deles; o estado tem 92.
QT_MUNICIPIOS_ESPERADA = 92

AGREGADO_PADRAO = "4714"
VARIAVEL_PADRAO = "93"
PERIODO_PADRAO = "2022"

CAMINHO_SEED_PADRAO = Path("sql/seed/04_POPULACAO_IBGE.sql")

IDENTIFICACAO_CLIENTE = "A3-Dashboard-Criminalidade-RJ/1.0 (script academico)"


# ---------------------------------------------------------------------------
# Leitura da API
# ---------------------------------------------------------------------------


def buscar_populacao(agregado: str, variavel: str, periodo: str) -> dict[int, int]:
    """Devolve {codigo IBGE do municipio: populacao} para o estado do RJ.

    Levanta RuntimeError com mensagem legivel em qualquer falha de rede ou de
    formato, para o erro aparecer no terminal em vez de virar um traceback.
    """
    url = URL_API.format(agregado=agregado, periodo=periodo, variavel=variavel)
    requisicao = urllib.request.Request(
        url, headers={"User-Agent": IDENTIFICACAO_CLIENTE}
    )

    try:
        with urllib.request.urlopen(requisicao, timeout=60) as resposta:
            corpo = json.loads(resposta.read().decode("utf-8"))
    except urllib.error.URLError as erro:
        raise RuntimeError(f"nao foi possivel falar com a API do IBGE: {erro}") from erro
    except json.JSONDecodeError as erro:
        raise RuntimeError(f"a API do IBGE devolveu algo que nao e JSON: {erro}") from erro

    return _extrair_series(corpo, periodo)


def _extrair_series(corpo: object, periodo: str) -> dict[int, int]:
    """Converte a resposta aninhada do SIDRA em um dicionario simples.

    O formato e: [ { resultados: [ { series: [ { localidade, serie } ] } ] } ].
    Toda a navegacao defensiva fica concentrada aqui para o resto do script
    trabalhar com um dicionario e nada mais.
    """
    if not isinstance(corpo, list) or not corpo:
        raise RuntimeError("a resposta da API veio vazia ou em formato inesperado")

    populacao: dict[int, int] = {}

    for variavel in corpo:
        for resultado in variavel.get("resultados", []):
            for serie in resultado.get("series", []):
                codigo_bruto = serie.get("localidade", {}).get("id")
                valor_bruto = serie.get("serie", {}).get(periodo)

                if codigo_bruto is None or valor_bruto in (None, "...", "-", "X"):
                    continue

                try:
                    codigo_ibge = int(codigo_bruto)
                    quantidade = int(float(valor_bruto))
                except (TypeError, ValueError):
                    continue

                if quantidade > 0:
                    populacao[codigo_ibge] = quantidade

    if not populacao:
        raise RuntimeError(
            "a API respondeu, mas nenhuma populacao foi lida - conferir "
            "agregado, variavel e periodo"
        )

    return populacao


# ---------------------------------------------------------------------------
# Geracao do SQL
# ---------------------------------------------------------------------------


def montar_seed(
    populacao: dict[int, int], agregado: str, variavel: str, periodo: str
) -> str:
    """Monta o conteudo do arquivo de seed, no padrao dos outros scripts SQL."""
    linhas = [
        "-- " + "=" * 72,
        "-- PROJETO : A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)",
        "-- ARQUIVO : 04_POPULACAO_IBGE.sql",
        "-- ASSUNTO : Populacao dos municipios do RJ para as taxas por 100 mil",
        "--",
        "-- ARQUIVO GERADO - nao editar a mao.",
        "-- Para regerar: python3 -I scripts/gerar_populacao_ibge.py",
        "--",
        f"-- FONTE   : IBGE, API de agregados (SIDRA), agregado {agregado},",
        f"--           variavel {variavel}, periodo {periodo}",
        f"-- MUNICIPIOS LIDOS: {len(populacao)}",
        "--",
        "-- ORDEM   : executar depois de",
        "--           sql/migrations/03_04_MUNICIPIO_POPULACAO.sql",
        "-- " + "=" * 72,
        "",
        "USE seg_dashboard;",
        "",
        "-- changeset paulo.alves:20261123-011",
        "-- comment: Carga da populacao dos municipios (fonte IBGE)",
        "",
        "START TRANSACTION;",
        "",
    ]

    for codigo_ibge in sorted(populacao):
        quantidade = populacao[codigo_ibge]
        linhas.append(
            "UPDATE SEG_MUNICIPIO "
            f"SET MUNI_QT_POPULACAO = {quantidade}, MUNI_AA_POPULACAO = {periodo} "
            f"WHERE MUNI_CD_IBGE = {codigo_ibge};"
        )

    linhas += [
        "",
        "COMMIT;",
        "",
        "-- Conferencia: nenhuma linha aqui significa populacao completa.",
        "SELECT MUNI_CD_IBGE, MUNI_NM_MUNICIPIO",
        "FROM SEG_MUNICIPIO",
        "WHERE MUNI_QT_POPULACAO IS NULL",
        "ORDER BY MUNI_NM_MUNICIPIO;",
        "",
    ]

    return "\n".join(linhas)


# ---------------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------------


def ler_argumentos(argv: list[str] | None = None) -> argparse.Namespace:
    analisador = argparse.ArgumentParser(
        description="Gera o seed SQL de populacao dos municipios do RJ (fonte IBGE).",
    )
    analisador.add_argument("--agregado", default=AGREGADO_PADRAO)
    analisador.add_argument("--variavel", default=VARIAVEL_PADRAO)
    analisador.add_argument("--periodo", default=PERIODO_PADRAO)
    analisador.add_argument(
        "--saida",
        type=Path,
        default=CAMINHO_SEED_PADRAO,
        help=f"arquivo a escrever (padrao: {CAMINHO_SEED_PADRAO})",
    )
    return analisador.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    argumentos = ler_argumentos(argv)

    print(
        f"Lendo populacao no IBGE (agregado {argumentos.agregado}, "
        f"variavel {argumentos.variavel}, periodo {argumentos.periodo})..."
    )

    try:
        populacao = buscar_populacao(
            argumentos.agregado, argumentos.variavel, argumentos.periodo
        )
    except RuntimeError as erro:
        print(f"ERRO: {erro}", file=sys.stderr)
        return 1

    print(f"{len(populacao)} municipios lidos.")

    if len(populacao) < QT_MUNICIPIOS_ESPERADA:
        print(
            f"ERRO: o estado do RJ tem {QT_MUNICIPIOS_ESPERADA} municipios e a "
            f"API devolveu {len(populacao)}. Seed NAO gerado, para nao produzir "
            "taxa sobre populacao parcial.",
            file=sys.stderr,
        )
        return 1

    argumentos.saida.parent.mkdir(parents=True, exist_ok=True)
    argumentos.saida.write_text(
        montar_seed(
            populacao, argumentos.agregado, argumentos.variavel, argumentos.periodo
        ),
        encoding="utf-8",
    )

    print(f"Seed escrito em {argumentos.saida}")
    print("Proximo passo: aplicar o arquivo no banco (ver sql/RUNBOOK.md).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
