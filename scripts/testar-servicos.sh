#!/usr/bin/env bash
set -u

# Issue #20: testa cada servico isoladamente sem publicar portas adicionais.
# As chamadas HTTP acontecem dentro do proprio container de cada servico.

FALHAS=0
AUTH_PARADO=0

limpar() {
  if [ "$AUTH_PARADO" -eq 1 ]; then
    docker compose start auth-service >/dev/null 2>&1 || true
  fi
}
trap limpar EXIT

echo "== Verificando containers =="
if ! docker compose ps --status running --services | grep -qx "auth-service"; then
  echo "[FALHA] auth-service nao esta em execucao. Rode: docker compose up -d --build"
  exit 1
fi
if ! docker compose ps --status running --services | grep -qx "produtos-service"; then
  echo "[FALHA] produtos-service nao esta em execucao. Rode: docker compose up -d --build"
  exit 1
fi

echo
echo "== Teste isolado do auth-service =="
if docker compose exec -T auth-service python - <<'PY'
import json
import sys
import time
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:3001"
EMAIL = f"isolado.{int(time.time())}@techstore.local"
SENHA = "123456"
falhas = 0


def chamada(metodo, caminho, dados=None, token=None):
    corpo = None if dados is None else json.dumps(dados).encode()
    req = urllib.request.Request(BASE + caminho, data=corpo, method=metodo)
    if dados is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            texto = resp.read().decode()
            return resp.status, json.loads(texto) if texto else {}
    except urllib.error.HTTPError as exc:
        texto = exc.read().decode()
        return exc.code, json.loads(texto) if texto else {}


def verifica(nome, esperado, obtido):
    global falhas
    if esperado == obtido:
        print(f"[OK]    {nome} (status {obtido})")
    else:
        print(f"[FALHA] {nome} (esperado {esperado}, veio {obtido})")
        falhas += 1


status, _ = chamada("GET", "/auth/health")
verifica("Saude do auth-service", 200, status)

usuario = {"nome": "Teste Isolado", "email": EMAIL, "senha": SENHA}
status, _ = chamada("POST", "/auth/register", usuario)
verifica("Cadastro de usuario", 201, status)

status, _ = chamada("POST", "/auth/register", usuario)
verifica("Cadastro duplicado", 409, status)

status, resposta = chamada("POST", "/auth/login", {"email": EMAIL, "senha": SENHA})
verifica("Login valido", 200, status)
token = resposta.get("token", "")
if not token:
    print("[FALHA] Login nao devolveu token")
    falhas += 1
else:
    status, _ = chamada("GET", "/auth/me", token=token)
    verifica("Consulta /auth/me", 200, status)

status, _ = chamada("POST", "/auth/login", {"email": EMAIL, "senha": "errada"})
verifica("Login invalido", 401, status)

sys.exit(1 if falhas else 0)
PY
then
  echo "[OK]    auth-service passou nos testes isolados"
else
  echo "[FALHA] auth-service falhou nos testes isolados"
  FALHAS=$((FALHAS + 1))
fi

echo
echo "== Parando auth-service para provar a independencia de produtos =="
if docker compose stop auth-service >/dev/null; then
  AUTH_PARADO=1
else
  echo "[FALHA] Nao foi possivel parar auth-service"
  exit 1
fi

echo
echo "== Teste isolado do produtos-service =="
if docker compose exec -T produtos-service python - <<'PY'
import datetime
import json
import os
import sys
import urllib.error
import urllib.request

import jwt

BASE = "http://127.0.0.1:3002"
falhas = 0


def chamada(metodo, caminho, dados=None, token=None):
    corpo = None if dados is None else json.dumps(dados).encode()
    req = urllib.request.Request(BASE + caminho, data=corpo, method=metodo)
    if dados is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            texto = resp.read().decode()
            return resp.status, json.loads(texto) if texto else {}
    except urllib.error.HTTPError as exc:
        texto = exc.read().decode()
        return exc.code, json.loads(texto) if texto else {}


def verifica(nome, esperado, obtido):
    global falhas
    if esperado == obtido:
        print(f"[OK]    {nome} (status {obtido})")
    else:
        print(f"[FALHA] {nome} (esperado {esperado}, veio {obtido})")
        falhas += 1


agora = datetime.datetime.now(datetime.timezone.utc)
token = jwt.encode(
    {
        "sub": "teste-isolado",
        "email": "isolado@techstore.local",
        "iat": agora,
        "exp": agora + datetime.timedelta(minutes=10),
    },
    os.environ["JWT_SECRET"],
    algorithm="HS256",
)

status, _ = chamada("GET", "/produtos")
verifica("Listagem publica", 200, status)

produto = {
    "nome": "Mouse isolado",
    "descricao": "Teste direto no servico",
    "preco": 79.90,
    "estoque": 25,
}
status, _ = chamada("POST", "/produtos", produto)
verifica("Cadastro sem token e recusado", 401, status)

status, resposta = chamada("POST", "/produtos", produto, token)
verifica("Cadastro com token proprio", 201, status)
produto_id = resposta.get("id")

if not produto_id:
    print("[FALHA] Cadastro nao devolveu ID")
    falhas += 1
else:
    status, _ = chamada("GET", f"/produtos/{produto_id}")
    verifica("Consulta por ID", 200, status)

    status, _ = chamada("PUT", f"/produtos/{produto_id}", {"preco": 69.90}, token)
    verifica("Atualizacao parcial", 200, status)

    status, _ = chamada("DELETE", f"/produtos/{produto_id}", token=token)
    verifica("Exclusao", 200, status)

    status, _ = chamada("GET", f"/produtos/{produto_id}")
    verifica("Produto removido", 404, status)

sys.exit(1 if falhas else 0)
PY
then
  echo "[OK]    produtos-service passou com auth-service parado"
else
  echo "[FALHA] produtos-service falhou nos testes isolados"
  FALHAS=$((FALHAS + 1))
fi

docker compose start auth-service >/dev/null
AUTH_PARADO=0

echo
if [ "$FALHAS" -eq 0 ]; then
  echo "Tudo certo: os dois servicos funcionam isoladamente."
else
  echo "$FALHAS grupo(s) de teste falharam."
  exit 1
fi

