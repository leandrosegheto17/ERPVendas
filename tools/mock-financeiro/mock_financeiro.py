#!/usr/bin/env python3
"""
Mock do Financeiro (ERP Vendas) — T05 / ADR-009 / RF-26.

Servidor HTTP minimo, somente com a biblioteca padrao do Python (sem
dependencias externas), que simula o servico Financeiro (C#) descrito no
contrato v1.0 (`docs/contrato-api-financeiro.md`). Serve para desenvolver e
demonstrar a integracao (ADR-004/005/006) sem depender do C# real.

Rotas de negocio (contrato v1.0):
  POST /api/vendas/quitacao
  POST /api/vendas/cancelamento
  GET  /api/vendas/{id}/status

Rota administrativa (fora do contrato v1.0, so para teste):
  GET|POST /_modo?m=ok|recusa|erro500|timeout|timeout-post|offline-simulado

O modo afeta as 3 rotas de negocio (todas), ate ser trocado de novo. Estado
das vendas (status/dataQuitacao) fica em memoria, perdido ao reiniciar.

Uso:
  python mock_financeiro.py [--host 127.0.0.1] [--port 8080] [--modo ok]

Ver README.md neste diretorio para exemplos de `curl`.
"""

from __future__ import annotations

import argparse
import json
import socket
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

MODOS_VALIDOS = ("ok", "recusa", "erro500", "timeout", "timeout-post", "offline-simulado")

# Atraso (em segundos) usado no modo "timeout". O cliente Delphi (ADR-004) usa
# timeout padrao de 10 s lido do INI; por isso o mock espera mais que isso
# antes de responder (quando chega a responder).
TIMEOUT_DELAY_SEGUNDOS = 11

# Estado global, protegido por lock (ThreadingHTTPServer atende em threads).
_lock = threading.Lock()
_modo_atual = "ok"
# vendaId (str) -> {"status": "Pendente"|"Quitada"|"Cancelada", "dataQuitacao": str|None}
_vendas: dict[str, dict] = {}


def _agora_iso() -> str:
    """Data/hora atual em ISO 8601, UTC como referencia interna, mas SEM
    sufixo de timezone explicito ("Z") na string — formato usado por
    `docs/contrato-api-financeiro.md` (v1.0) e compativel com o parser
    Delphi de T33 (TFormatSettings invariante, sem timezone)."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")


def _get_modo() -> str:
    with _lock:
        return _modo_atual


def _set_modo(novo: str) -> bool:
    global _modo_atual
    if novo not in MODOS_VALIDOS:
        return False
    with _lock:
        _modo_atual = novo
    return True


def _venda_estado(venda_id: str) -> dict:
    with _lock:
        return _vendas.setdefault(venda_id, {"status": "Pendente", "dataQuitacao": None})


def _atualizar_venda(venda_id: str, status: str, data_quitacao: str | None = None) -> None:
    with _lock:
        estado = _vendas.setdefault(venda_id, {"status": "Pendente", "dataQuitacao": None})
        estado["status"] = status
        if data_quitacao is not None:
            estado["dataQuitacao"] = data_quitacao


class MockFinanceiroHandler(BaseHTTPRequestHandler):
    server_version = "MockFinanceiro/1.0"
    protocol_version = "HTTP/1.1"

    # ---- helpers -----------------------------------------------------

    def _ler_corpo_json(self) -> dict | None:
        tamanho = int(self.headers.get("Content-Length", 0) or 0)
        bruto = self.rfile.read(tamanho) if tamanho > 0 else b""
        if not bruto:
            return {}
        try:
            return json.loads(bruto.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None

    def _responder_json(self, status_code: int, corpo: dict) -> None:
        payload = json.dumps(corpo, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _atraso_timeout_post(self) -> None:
        """Modo timeout-post: o efeito do POST ja foi registrado no estado;
        so a RESPOSTA atrasa (> timeout do cliente), para o GET /status de
        reconciliacao (T41) devolver o estado novo sem atraso. O POST e
        processado uma unica vez (o log do mock mostra 1 POST)."""
        if _get_modo() == "timeout-post":
            time.sleep(TIMEOUT_DELAY_SEGUNDOS)

    def _derrubar_conexao_sem_resposta(self) -> None:
        """Simula 'offline-simulado': fecha o socket sem escrever nenhuma
        resposta HTTP, reproduzindo uma conexao recusada/derrubada do lado do
        cliente (mapeado para Indisponivel em ADR-004)."""
        self.close_connection = True
        try:
            self.connection.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        try:
            self.connection.close()
        except OSError:
            pass

    def _aplicar_modo_comum(self) -> str | None:
        """Aplica o modo simulado atual a qualquer rota de negocio. Retorna
        None se a rota deve seguir o fluxo normal ("ok"), ou uma string
        indicando que a resposta ja foi tratada (ou a conexao derrubada)."""
        modo = _get_modo()

        if modo == "offline-simulado":
            self._derrubar_conexao_sem_resposta()
            return "tratado"

        if modo == "timeout":
            time.sleep(TIMEOUT_DELAY_SEGUNDOS)
            # Depois do atraso, responde normalmente (o cliente real ja deve
            # ter estourado o timeout de 10 s e classificado como Indisponivel).
            return None

        if modo == "timeout-post":
            # Atraso so nos POSTs e feito dentro das rotas (efeito registrado
            # ANTES do atraso); GET /status segue normal, sem atraso.
            return None

        if modo == "recusa":
            self._responder_json(
                422,
                {"mensagem": "Operacao recusada pelo Financeiro (modo simulado: recusa)."},
            )
            return "tratado"

        if modo == "erro500":
            self._responder_json(
                500,
                {"mensagem": "Erro interno simulado no Financeiro (modo simulado: erro500)."},
            )
            return "tratado"

        return None  # modo == "ok"

    def log_message(self, format, *args):  # noqa: A002 - assinatura da stdlib
        # Log simples em stdout, sem dado sensivel (so metodo/rota/status).
        print("[mock-financeiro] %s - %s" % (self.address_string(), format % args))

    # ---- rotas ---------------------------------------------------------

    def do_GET(self):
        parsed = urlparse(self.path)
        partes = [p for p in parsed.path.split("/") if p]

        if parsed.path == "/_modo":
            # GET tambem aceita "?m=..." para trocar o modo (conveniencia de
            # `curl` sem precisar de -X POST); sem "m", so relata o modo atual.
            qs = parse_qs(parsed.query)
            if "m" in qs:
                self._rota_post_modo(parsed)
            else:
                self._rota_get_modo(parsed)
            return

        # GET /api/vendas/{id}/status
        if len(partes) == 4 and partes[0] == "api" and partes[1] == "vendas" and partes[3] == "status":
            self._rota_status(partes[2])
            return

        self._responder_json(404, {"mensagem": "Rota nao encontrada."})

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path == "/_modo":
            self._rota_post_modo(parsed)
            return

        if parsed.path == "/api/vendas/quitacao":
            self._rota_quitacao()
            return

        if parsed.path == "/api/vendas/cancelamento":
            self._rota_cancelamento()
            return

        self._responder_json(404, {"mensagem": "Rota nao encontrada."})

    # ---- implementacao das rotas ---------------------------------------

    def _rota_get_modo(self, parsed) -> None:
        self._responder_json(200, {"modo": _get_modo(), "modosValidos": list(MODOS_VALIDOS)})

    def _rota_post_modo(self, parsed) -> None:
        qs = parse_qs(parsed.query)
        novo = (qs.get("m") or [None])[0]
        if novo is None:
            self._responder_json(400, {"mensagem": "Parametro 'm' obrigatorio."})
            return
        if not _set_modo(novo):
            self._responder_json(
                400,
                {
                    "mensagem": "Modo invalido.",
                    "modosValidos": list(MODOS_VALIDOS),
                },
            )
            return
        self._responder_json(200, {"modo": _get_modo()})

    def _rota_quitacao(self) -> None:
        if self._aplicar_modo_comum() is not None:
            return

        corpo = self._ler_corpo_json()
        if corpo is None:
            self._responder_json(400, {"mensagem": "Corpo JSON invalido."})
            return

        venda_id = str(corpo.get("vendaId", "")).strip()
        if not venda_id:
            self._responder_json(400, {"mensagem": "'vendaId' obrigatorio."})
            return

        data_quitacao = _agora_iso()
        _atualizar_venda(venda_id, "Quitada", data_quitacao)
        self._atraso_timeout_post()
        self._responder_json(
            200,
            {"vendaId": venda_id, "status": "Quitada", "dataQuitacao": data_quitacao},
        )

    def _rota_cancelamento(self) -> None:
        if self._aplicar_modo_comum() is not None:
            return

        corpo = self._ler_corpo_json()
        if corpo is None:
            self._responder_json(400, {"mensagem": "Corpo JSON invalido."})
            return

        venda_id = str(corpo.get("vendaId", "")).strip()
        if not venda_id:
            self._responder_json(400, {"mensagem": "'vendaId' obrigatorio."})
            return

        motivo = corpo.get("motivo")
        _atualizar_venda(venda_id, "Cancelada")
        self._atraso_timeout_post()
        resposta = {"vendaId": venda_id, "status": "Cancelada"}
        if motivo:
            resposta["motivo"] = motivo
        self._responder_json(200, resposta)

    def _rota_status(self, venda_id: str) -> None:
        if self._aplicar_modo_comum() is not None:
            return

        estado = _venda_estado(venda_id)
        resposta = {"vendaId": venda_id, "status": estado["status"]}
        if estado["dataQuitacao"]:
            resposta["dataQuitacao"] = estado["dataQuitacao"]
        self._responder_json(200, resposta)


def main() -> None:
    parser = argparse.ArgumentParser(description="Mock do Financeiro (stdlib, T05/ADR-009).")
    parser.add_argument("--host", default="127.0.0.1", help="Host de escuta (padrao 127.0.0.1).")
    parser.add_argument("--port", type=int, default=8080, help="Porta de escuta (padrao 8080).")
    parser.add_argument(
        "--modo",
        default="ok",
        choices=MODOS_VALIDOS,
        help="Modo inicial (padrao 'ok'); pode ser trocado depois via /_modo.",
    )
    args = parser.parse_args()

    _set_modo(args.modo)

    servidor = ThreadingHTTPServer((args.host, args.port), MockFinanceiroHandler)
    print(f"[mock-financeiro] escutando em http://{args.host}:{args.port} (modo inicial: {args.modo})")
    print("[mock-financeiro] Ctrl+C para encerrar.")
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        servidor.server_close()


if __name__ == "__main__":
    main()
