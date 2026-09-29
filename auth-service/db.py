import os
import time

import psycopg2


def get_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        user=os.getenv("DB_USER", "techstore"),
        password=os.getenv("DB_PASSWORD", "techstore"),
        dbname=os.getenv("DB_NAME", "techstore"),
    )


def init_db(tentativas=10):
    """Cria o schema 'auth' e a tabela de usuários (schema separado por serviço).
    Tenta várias vezes porque o banco pode demorar a iniciar no Docker."""
    for i in range(1, tentativas + 1):
        try:
            conn = get_connection()
            with conn, conn.cursor() as cur:
                cur.execute("CREATE SCHEMA IF NOT EXISTS auth")
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS auth.usuarios (
                        id SERIAL PRIMARY KEY,
                        nome VARCHAR(100) NOT NULL,
                        email VARCHAR(150) UNIQUE NOT NULL,
                        senha_hash VARCHAR(255) NOT NULL,
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