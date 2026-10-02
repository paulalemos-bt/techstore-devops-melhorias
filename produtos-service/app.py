import os
from functools import wraps

import jwt
from flask import Flask, jsonify, request

from db import get_connection, init_db

app = Flask(__name__)

# Precisa ser o MESMO segredo usado pelo auth-service para validar os tokens
JWT_SECRET = os.getenv("JWT_SECRET", "troque-este-segredo")

CAMPOS = ["nome", "descricao", "preco", "estoque"]
COLUNAS = "id, nome, descricao, preco, estoque"

# Cria o schema e a tabela de produtos no banco (produtos-db)
init_db()


def consultar(sql, params=(), um=False):
    """Executa uma consulta no banco de produtos e devolve as linhas (ou uma só)."""
    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(sql, params)
            if cur.description is None:
                return None
            return cur.fetchone() if um else cur.fetchall()
    finally:
        conn.close()


def produto_para_dict(linha):
    return {
        "id": linha[0],
        "nome": linha[1],
        "descricao": linha[2],
        "preco": float(linha[3]),
        "estoque": linha[4],
    }


def erro_de_tipo(dados):
    """Confere o tipo dos campos enviados. Devolve a mensagem de erro ou None."""
    if "nome" in dados and (not isinstance(dados["nome"], str) or not dados["nome"].strip()):
        return "nome deve ser um texto não vazio"
    if "descricao" in dados and not isinstance(dados["descricao"], str):
        return "descricao deve ser um texto"
    if "preco" in dados:
        preco = dados["preco"]
        if isinstance(preco, bool) or not isinstance(preco, (int, float)) or preco < 0:
            return "preco deve ser um número maior ou igual a 0"
    if "estoque" in dados:
        estoque = dados["estoque"]
        if isinstance(estoque, bool) or not isinstance(estoque, int) or estoque < 0:
            return "estoque deve ser um inteiro maior ou igual a 0"
    return None


def exige_token(funcao):
    """Protege a rota: só passa quem enviar um token JWT válido (gerado pelo auth-service)."""

    @wraps(funcao)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return jsonify({"erro": "Token ausente"}), 401
        try:
            jwt.decode(header[7:], JWT_SECRET, algorithms=["HS256"])
        except jwt.PyJWTError:
            return jsonify({"erro": "Token inválido ou expirado"}), 401
        return funcao(*args, **kwargs)

    return wrapper


# LISTAGEM (pública)
@app.route("/produtos", methods=["GET"])
def listar_produtos():
    linhas = consultar(f"SELECT {COLUNAS} FROM produtos.produtos ORDER BY id")
    return jsonify([produto_para_dict(l) for l in linhas]), 200


# BUSCAR UM PRODUTO (público)
@app.route("/produtos/<int:produto_id>", methods=["GET"])
def buscar_produto(produto_id):
    linha = consultar(
        f"SELECT {COLUNAS} FROM produtos.produtos WHERE id = %s", (produto_id,), um=True
    )
    if not linha:
        return jsonify({"erro": "Produto não encontrado"}), 404
    return jsonify(produto_para_dict(linha)), 200


# CADASTRO (exige token)
@app.route("/produtos", methods=["POST"])
@exige_token
def cadastrar_produto():
    dados = request.get_json(silent=True) or {}

    if not all(campo in dados for campo in CAMPOS):
        return jsonify({"erro": "Campos obrigatórios: nome, descricao, preco, estoque"}), 400
    erro = erro_de_tipo(dados)
    if erro:
        return jsonify({"erro": erro}), 400

    linha = consultar(
        "INSERT INTO produtos.produtos (nome, descricao, preco, estoque) "
        f"VALUES (%s, %s, %s, %s) RETURNING {COLUNAS}",
        (dados["nome"].strip(), dados["descricao"], dados["preco"], dados["estoque"]),
        um=True,
    )
    return jsonify(produto_para_dict(linha)), 201


# EDIÇÃO (exige token) - pode enviar só os campos que quer mudar
@app.route("/produtos/<int:produto_id>", methods=["PUT"])
@exige_token
def editar_produto(produto_id):
    dados = request.get_json(silent=True) or {}

    alteracoes = {campo: dados[campo] for campo in CAMPOS if campo in dados}
    if not alteracoes:
        return jsonify({"erro": "Envie ao menos um campo: nome, descricao, preco ou estoque"}), 400
    erro = erro_de_tipo(alteracoes)
    if erro:
        return jsonify({"erro": erro}), 400
    if "nome" in alteracoes:
        alteracoes["nome"] = alteracoes["nome"].strip()

    # As colunas vêm da lista fixa CAMPOS, então é seguro montar o SET assim
    set_sql = ", ".join(f"{coluna} = %s" for coluna in alteracoes)
    linha = consultar(
        f"UPDATE produtos.produtos SET {set_sql} WHERE id = %s RETURNING {COLUNAS}",
        list(alteracoes.values()) + [produto_id],
        um=True,
    )
    if not linha:
        return jsonify({"erro": "Produto não encontrado"}), 404
    return jsonify(produto_para_dict(linha)), 200


# REMOÇÃO (exige token)
@app.route("/produtos/<int:produto_id>", methods=["DELETE"])
@exige_token
def remover_produto(produto_id):
    removido = consultar(
        "DELETE FROM produtos.produtos WHERE id = %s RETURNING id", (produto_id,), um=True
    )
    if not removido:
        return jsonify({"erro": "Produto não encontrado"}), 404
    return jsonify({"mensagem": "Produto removido", "id": produto_id}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3002)