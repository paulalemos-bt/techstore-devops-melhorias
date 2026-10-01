FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 3002

RUN useradd -m appuser
USER appuser

CMD ["gunicorn", "--bind", "0.0.0.0:3002", "app:app"]