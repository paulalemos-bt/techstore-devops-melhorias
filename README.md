TechStore — Evolução da Arquitetura (Problemática 01)

Projeto integrador de DevOps — Módulo 1.

Problemática recebida

A aplicação inicial da TechStore concentra diversas responsabilidades (autenticação,
usuários e produtos) em uma única aplicação monolítica. Com o crescimento da
plataforma, essa arquitetura passou a dificultar a manutenção, evolução e
escalabilidade independente de suas funcionalidades.

Solução proposta

Evolução da arquitetura monolítica para um modelo com serviços separados por
responsabilidade, comunicando-se através de um API Gateway:

- Serviço de Autenticação/Usuários — login, cadastro, emissão de JWT
- Serviço de Produtos — CRUD do catálogo
- API Gateway — ponto único de entrada, roteando requisições para o serviço correto
- Banco de Dados — instância única, com schemas separados por serviço

Estrutura do repositório

- `/auth-service` — código do serviço de autenticação/usuários
- `/produtos-service` — código do serviço de produtos
- `/gateway` — configuração do API Gateway
- `/docs` — documentação completa do projeto
- `/terraform` — infraestrutura como código (containers)
- `/ansible` — automação de provisionamento do ambiente

Equipe

Artur Leone, 
Ana Paula Lemos, 
Gustavo Henrique, 
Thiago Renan.
