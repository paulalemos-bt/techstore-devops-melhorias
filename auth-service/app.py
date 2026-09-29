import datetime
import os

import jwt
import psycopg2
from flask import Flask, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

from db import get_connection, init_db

app = Flask(__name__)

JWT_SECRET = os.getenv("JWT_SECRET", "troque-este-segredo")
JWT_EXPIRA_MINUTOS = int(os.getenv("JWT_EXPIRA_MINUTOS", "60"))

init_db()


@app.get("/auth/health")
def health():
    return jsonify(status="ok", service="auth")


# CADASTRO
@app.post("/auth/register")
def register():
    dados = request.get_json(silent=True) or {}
    nome = dados.get("nome")
    email = dados.get("email")
    senha = dados.get("senha")

    if not nome or not email or not senha:
        return jsonify(erro="nome, email e senha são obrigatórios"), 400
    if len(senha) < 6:
        return jsonify(erro="a senha deve ter pelo menos 6 caracteres"), 400

    senha_hash = generate_password_hash(senha)
    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO auth.usuarios (nome, email, senha_hash) "
                "VALUES (%s, %s, %s) RETURNING id, nome, email",
                (nome, email.lower(), senha_hash),
            )
            id_, nome_, email_ = cur.fetchone()
        return jsonify(id=id_, nome=nome_, email=email_), 201
    except psycopg2.errors.UniqueViolation:
        return jsonify(erro="email já cadastrado"), 409
    finally:
        conn.close()


# LOGIN + GERAÇÃO DO TOKEN JWT
@app.post("/auth/login")
def login():
    dados = request.get_json(silent=True) or {}
    email = dados.get("email")
    senha = dados.get("senha")

    if not email or not senha:
        return jsonify(erro="email e senha são obrigatórios"), 400

    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "SELECT id, email, senha_hash FROM auth.usuarios WHERE email = %s",
                (email.lower(),),
            )
            usuario = cur.fetchone()
    finally:
        conn.close()

    # Mesma mensagem para email/senha errados (não revela qual está errado)
    if not usuario or not check_password_hash(usuario[2], senha):
        return jsonify(erro="credenciais inválidas"), 401

    agora = datetime.datetime.now(datetime.timezone.utc)
    token = jwt.encode(
        {
            "sub": str(usuario[0]),
            "email": usuario[1],
            "iat": agora,
            "exp": agora + datetime.timedelta(minutes=JWT_EXPIRA_MINUTOS),
        },
        JWT_SECRET,
        algorithm="HS256",
    )
    return jsonify(token=token, tipo="Bearer", expira_em_minutos=JWT_EXPIRA_MINUTOS)


# ROTA PROTEGIDA (valida o token) - útil para testar no Postman
@app.get("/auth/me")
def me():
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return jsonify(erro="token ausente"), 401
    try:
        payload = jwt.decode(header[7:], JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        return jsonify(erro="token inválido ou expirado"), 401
    return jsonify(id=payload["sub"], email=payload["email"])
