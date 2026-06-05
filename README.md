# Desafio Técnico — DevOps Pleno — BSA Tech

Ambiente de produção containerizado com **Ghost + MySQL + Nginx (HTTPS) + Prometheus + Grafana + AlertManager**, pronto para subir com um único comando.

## Desafio (Orientação original)

**Objetivo**: Criar um ambiente com docker-compose para executar um blog e seus serviços, funcional ao ser clonado e iniciado com docker compose up.

Escolha uma stack:

- PHP: WordPress
- Node.js: Ghost <- Preferencia

Banco de dados: MySQL ou MariaDB.

O que esperamos do ambiente :

- docker-compose (sintaxe mais recente), o banco e o blog escolhido, com os serviços iniciando na ordem correta — aguardando o banco estar pronto.
- Persistência de todos os dados por meio de volumes.
- Nginx com configuração personalizada: HTTPS, redirecionamento de HTTP para HTTPS, certificado (autoassinado ou Let's Encrypt — documente os comandos usados para gerá-lo), cabeçalhos de segurança, controle de acesso a arquivos e diretórios sensíveis, e o que mais você julgar importante.
- Uma imagem própria publicada em um registro público no Docker Hub e consumida pelo ambiente. Documente os comandos.
- Tratamento adequado de segredos — sem credenciais expostas no repositório.
- Backup e restore do banco automatizados via shell, com o restore documentado e testável.
- Monitoramento dos serviços (ex.: Prometheus e Grafana).
- Alertas relevantes, incluindo uso de disco/volume — com uma forma automatizada de forçar as condições, para que possamos validar o disparo.
- Testes que validem o ambiente após a subida.
- Um pipeline de CI que valide os títulos dos Pull Requests seguindo commits semânticos.

Fique à vontade para incluir qualquer outra coisa que considere relevante para um ambiente de produção — e para priorizar o que faz sentido. Faça as escolhas que você defenderia no dia a dia e explique-as no README.

Entrega :

- Repositório público (GitHub ou GitLab), com README.md explicando suas decisões e como executar tudo.
- Histórico de commits semânticos.
- git clone + docker compose up deve subir o ambiente funcional.

---

## Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| Docker | 24+ |
| Docker Compose plugin (`docker compose`) | v2 |
| openssl | qualquer versão recente |
| bash | 4+ |

## Como executar

```bash
# 1. Clone o repositório
git clone https://github.com/devpolatto/devops-challenge-bsatech.git
cd devops-challenge-bsatech

# 2. Gere o .env com senhas aleatórias seguras
./scripts/setup-env.sh

# 3. Suba o ambiente
docker compose up -d

# 4. (Opcional) Valide que tudo está saudável
./scripts/test-environment.sh
```

> O certificado SSL autoassinado é gerado automaticamente na primeira subida do Nginx — nenhum passo extra necessário.

## Serviços e URLs

| Serviço | URL | Credenciais |
|---|---|---|
| Blog Ghost | https://localhost | — |
| Ghost Admin | https://localhost/ghost | Configure no primeiro acesso |
| Prometheus | http://localhost:9090 | — |
| AlertManager | http://localhost:9093 | — |
| Grafana | http://localhost:3000 | `admin` / senha gerada pelo `setup-env.sh` |

> O navegador exibirá aviso de certificado autoassinado — clique em "Avançado → Prosseguir". Comportamento esperado e documentado.

---

## Imagem Docker Custom — `devpolatto/devops-challenge-nginx`

A imagem Nginx customizada está publicada publicamente no Docker Hub:
**[hub.docker.com/r/devpolatto/devops-challenge-nginx](https://hub.docker.com/r/devpolatto/devops-challenge-nginx)**

### O que há de custom nessa imagem

Baseada em `nginx:alpine`, ela embarca:
- `nginx.conf` com HTTPS, redirect HTTP→HTTPS, security headers e bloqueio de arquivos sensíveis
- `docker-entrypoint.sh` que gera o certificado SSL autoassinado automaticamente na primeira subida (sem pré-requisito manual)
- `openssl` instalado via `apk` para viabilizar a geração do certificado em runtime

### Publicação automatizada via CI/CD

O workflow `.github/workflows/docker-publish.yml` faz o build e push automaticamente a cada push na branch `master` que altere qualquer arquivo em `nginx/`. As tags geradas seguem o padrão:

| Tag | Descrição |
|---|---|
| `latest` | Sempre aponta para o build mais recente |
| `<7-char-sha>` | SHA curto do commit — rastreabilidade total entre imagem e código |

**Secrets necessários no repositório GitHub** (`Settings → Secrets → Actions`):

```
DOCKERHUB_USERNAME    — username no Docker Hub
DOCKERHUB_TOKEN       — Access Token (hub.docker.com → Account Settings → Security → New Access Token)
DOCKERHUB_REPOSITORY  — nome completo da imagem (ex: devpolatto/devops-challenge-nginx)
```

### Comandos manuais (referência)

Para rodar o processo fora da CI ou em ambiente sem GitHub Actions:

```bash
# 1. Autenticar no Docker Hub
docker login

# 2. Build com as duas tags
docker build \
  -t devpolatto/devops-challenge-nginx:latest \
  -t devpolatto/devops-challenge-nginx:$(git rev-parse --short HEAD) \
  ./nginx

# 3. Push de ambas as tags
docker push devpolatto/devops-challenge-nginx:latest
docker push devpolatto/devops-challenge-nginx:$(git rev-parse --short HEAD)

# 4. Verificar a imagem no registry
docker pull devpolatto/devops-challenge-nginx:latest
```

> **Nota:** O ambiente (`docker-compose.yml`) já está configurado para consumir `devpolatto/devops-challenge-nginx:latest` diretamente do Docker Hub — não há build local necessário para subir o ambiente.