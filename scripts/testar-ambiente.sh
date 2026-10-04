#!/usr/bin/env bash
# Testa o ambiente completo passando SEMPRE pelo gateway.
# Uso:  bash scripts/testar-ambiente.sh
#       BASE_URL=http://localhost:8080 bash scripts/testar-ambiente.sh

BASE_URL="${BASE_URL:-http://localhost:8080}"
EMAIL="teste$(date +%s)@email.com"
SENHA="123456"
FALHAS=0
CORPO="$(mktemp)"

# verifica NOME ESPERADO OBTIDO
verifica() {
  if [ "$2" = "$3" ]; then
    echo "[OK]    $1 (status $3)"
  else
    echo "[FALHA] $1 (esperado $2, veio $3)"
    FALHAS=$((FALHAS + 1))
  fi
}

# chamada MÉTODO CAMINHO [TOKEN] [JSON]  -> devolve o status e guarda o corpo
chamada() {
  local metodo="$1" caminho="$2" token="$3" json="$4"
  local args=(-s -o "$CORPO" -w "%{http_code}" -X "$metodo" "$BASE_URL$caminho")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$json" ] && args+=(-H "Content-Type: application/json" -d "$json")
  curl "${args[@]}"
}

echo "== Testando $BASE_URL =="

verifica "Gateway no ar (GET /health)" 200 "$(chamada GET /health)"

verifica "Cadastro de usuário (POST /auth/register)" 201 \
  "$(chamada POST /auth/register "" "{\"nome\":\"Teste\",\"email\":\"$EMAIL\",\"senha\":\"$SENHA\"}")"

verifica "Login (POST /auth/login)" 200 \
  "$(chamada POST /auth/login "" "{\"email\":\"$EMAIL\",\"senha\":\"$SENHA\"}")"
TOKEN="$(sed -n 's/.*"token": *"\([^"]*\)".*/\1/p' "$CORPO")"
[ -z "$TOKEN" ] && echo "[FALHA] token não encontrado na resposta do login" && FALHAS=$((FALHAS + 1))

verifica "Validar token (GET /auth/me)" 200 "$(chamada GET /auth/me "$TOKEN")"

verifica "Cadastrar produto SEM token é recusado" 401 \
  "$(chamada POST /produtos "" '{"nome":"Queijo","descricao":"500g","preco":32.5,"estoque":10}')"

verifica "Cadastrar produto COM token (POST /produtos)" 201 \
  "$(chamada POST /produtos "$TOKEN" '{"nome":"Queijo Coalho","descricao":"500g","preco":32.5,"estoque":10}')"
ID="$(sed -n 's/.*"id": *\([0-9][0-9]*\).*/\1/p' "$CORPO")"

verifica "Listar produtos (GET /produtos)" 200 "$(chamada GET /produtos)"
verifica "Editar produto (PUT /produtos/$ID)" 200 "$(chamada PUT "/produtos/$ID" "$TOKEN" '{"preco":35}')"
verifica "Remover produto (DELETE /produtos/$ID)" 200 "$(chamada DELETE "/produtos/$ID" "$TOKEN")"
verifica "Produto removido não é mais encontrado" 404 "$(chamada GET "/produtos/$ID")"
verifica "Rota inexistente no gateway" 404 "$(chamada GET /nao-existe)"

rm -f "$CORPO"
echo
if [ "$FALHAS" -eq 0 ]; then
  echo "Tudo certo: ambiente completo funcionando."
else
  echo "$FALHAS teste(s) falharam."
  exit 1
fi
