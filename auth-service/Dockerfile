FROM python:3.12-slim

WORKDIR /app

# Copia só as dependências primeiro (aproveita o cache do Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 3001

# Roda como usuário não-root (boa prática)
RUN useradd -m appuser
USER appuser

CMD ["gunicorn", "--bind", "0.0.0.0:3001", "app:app"]