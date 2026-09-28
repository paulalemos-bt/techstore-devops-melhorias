Contrato de Endpoints — TechStore

Todos os pedidos dos clientes entram pelo API Gateway, que encaminha para o serviço correto:
- Caminhos que começam com /auth vão para o Serviço de Autenticação
- Caminhos que começam com /produtos vão para o Serviço de Produtos

Os dados são enviados e recebidos no formato JSON.

---

## Serviço de Autenticação / Usuários

### POST /auth/registro
Cria um novo usuário.

Envia:
json
{ "nome": "Maria", "email": "maria@email.com", "senha": "123456" }

Recebe (201 - criado):
json
{ "id": 1, "nome": "Maria", "email": "maria@email.com" }

Erro (400): e-mail já cadastrado ou campo faltando.

POST /auth/login
Confere e-mail e senha e devolve um token (uma "pulseira de acesso").

Envia:
json
{ "email": "maria@email.com", "senha": "123456" }

Recebe (200 - ok):
json
{ "token": "abc123..." }

Erro (401): e-mail ou senha incorretos.

GET /auth/perfil
Mostra os dados do usuário logado. Exige o token no cabeçalho:
Authorization: Bearer <token>

Recebe (200):
json
{ "id": 1, "nome": "Maria", "email": "maria@email.com" }

Erro (401): token ausente ou inválido.



Serviço de Produtos

GET /produtos
Lista todos os produtos. Não exige token.

Recebe (200):
json
[ { "id": 1, "nome": "Mouse", "descricao": "Mouse sem fio", "preco": 79.90, "estoque": 25 } ]


GET /produtos/{id}
Mostra um produto específico.

Recebe (200): um objeto de produto como acima.
Erro (404): produto não encontrado.

POST /produtos
Cadastra um produto. Exige token.

Envia:
json
{ "nome": "Mouse", "descricao": "Mouse sem fio", "preco": 79.90, "estoque": 25 }

Recebe (201): o produto criado, com `id`.
Erro (400): campo faltando. Erro (401): sem token.

PUT /produtos/{id}
Altera um produto existente. Exige token.

Envia: os mesmos campos do POST.
Recebe (200): o produto atualizado.
Erro (404): produto não encontrado.

DELETE /produtos/{id}
Remove um produto. Exige token.

Recebe (204): sem conteúdo (deu certo).
Erro (404): produto não encontrado.
