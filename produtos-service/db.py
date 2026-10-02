import os
import time

import psycopg2


def get_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        user=os.getenv("DB_USER", "techstore"),
        password=os.getenv("DB_PASSWORD", "techstore"),
        dbname=os.getenv("DB_NAME", "produtos_db"),
    )


def init_db(tentativas=10):
    """Cria o schema 'produtos' e a tabela do catálogo (schema separado por serviço).
    Tenta várias vezes porque o banco pode demorar a iniciar no Docker."""
    for i in range(1, tentativas + 1):
        try:
            conn = get_connection()
            with conn, conn.cursor() as cur:
                cur.execute("CREATE SCHEMA IF NOT EXISTS produtos")
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS produtos.produtos (
                        id SERIAL PRIMARY KEY,
                        nome VARCHAR(150) NOT NULL,
                        descricao TEXT,
                        preco NUMERIC(10, 2) NOT NULL CHECK (preco >= 0),
                        estoque INTEGER NOT NULL DEFAULT 0 CHECK (estoque >= 0),
                        criado_em TIMESTAMP DEFAULT NOW()
                    )
                    """
                )
            conn.close()
            return
        except psycopg2.OperationalError:
            print(f"Aguardando banco ({i}/{tentativas})...", flush=True)
            if i == tentativas:
                raise
            time.sleep(3)