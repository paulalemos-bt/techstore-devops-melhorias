from flask import Flask, jsonify, request

app = Flask(__name__)

# Lista onde os produtos ficam guardados (some quando o serviço reinicia)
produtos = []
proximo_id = 1


@app.route("/produtos", methods=["GET"])
def listar_produtos():
    return jsonify(produtos), 200


@app.route("/produtos/<int:produto_id>", methods=["GET"])
def buscar_produto(produto_id):
    for produto in produtos:
        if produto["id"] == produto_id:
            return jsonify(produto), 200
    return jsonify({"erro": "Produto não encontrado"}), 404


@app.route("/produtos", methods=["POST"])
def cadastrar_produto():
    global proximo_id
    dados = request.get_json() or {}

    campos = ["nome", "descricao", "preco", "estoque"]
    if not all(campo in dados for campo in campos):
        return jsonify({"erro": "Campos obrigatórios: nome, descricao, preco, estoque"}), 400

    produto = {
        "id": proximo_id,
        "nome": dados["nome"],
        "descricao": dados["descricao"],
        "preco": dados["preco"],
        "estoque": dados["estoque"],
    }
    produtos.append(produto)
    proximo_id += 1
    return jsonify(produto), 201


@app.route("/produtos/<int:produto_id>", methods=["PUT"])
def editar_produto(produto_id):
    dados = request.get_json() or {}

    campos_editaveis = ["nome", "descricao", "preco", "estoque"]
    alteracoes = {campo: dados[campo] for campo in campos_editaveis if campo in dados}
    if not alteracoes:
        return jsonify({"erro": "Envie ao menos um campo: nome, descricao, preco ou estoque"}), 400

    for produto in produtos:
        if produto["id"] == produto_id:
            produto.update(alteracoes)
            return jsonify(produto), 200
    return jsonify({"erro": "Produto não encontrado"}), 404


@app.route("/produtos/<int:produto_id>", methods=["DELETE"])
def remover_produto(produto_id):
    for produto in produtos:
        if produto["id"] == produto_id:
            produtos.remove(produto)
            return jsonify({"mensagem": "Produto removido", "id": produto_id}), 200
    return jsonify({"erro": "Produto não encontrado"}), 404

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002)