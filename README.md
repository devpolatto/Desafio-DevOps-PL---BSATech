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

## Decisões técnicas

| Decisão | Escolha | Alternativa descartada | Motivo |
|---|---|---|---|
| Plataforma de blog | Ghost (Node.js) | WordPress (PHP) | Desafio indica preferência; stack mais moderna e leve |
| Banco de dados | MySQL 8.0 | MariaDB | Ghost tem compatibilidade nativa e testada com MySQL |
| Certificado SSL | Autoassinado (openssl) | Let's Encrypt | Let's Encrypt requer domínio público real; ambiente local não possui |
| Geração do certificado | Entrypoint do container Nginx | Pré-gerado e versionado | Zero pré-requisitos manuais: `git clone + docker compose up` sobe tudo |
| Imagem custom | Nginx com Dockerfile próprio | Nginx oficial sem customização | Desafio exige imagem em registro público; Nginx é o componente mais customizado |
| Gestão de segredos | `.env` + `.gitignore` | Docker Secrets | Docker Secrets requer Swarm mode; `.env` é o padrão para Compose standalone |
| Sistema de alertas | Prometheus + AlertManager | Grafana Alerting | AlertManager é o padrão da indústria; Grafana Alerting requer backend externo |
| Disparo de alerta de disco | Injeção via AlertManager API | `dd` para encher disco | Disco de 233 GB exigiria escrever ~172 GB — impraticável; API injection é padrão em testes de alerting |
| Automação de secrets | Terraform (IaC) | Configuração manual no GitHub UI | Reproduzível, auditável e sem segredos expostos; token do Docker Hub gerado e injetado automaticamente via pipeline |

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
| Blog Ghost (frontend) | https://localhost | — |
| Ghost Admin (painel) | https://localhost/ghost | Criadas no primeiro acesso |
| Prometheus | http://localhost:9090 | — |
| AlertManager | http://localhost:9093 | — |
| Grafana | http://localhost:3000 | `admin` / senha gerada pelo `setup-env.sh` |

> O navegador exibirá aviso de certificado autoassinado — clique em "Avançado → Prosseguir". Comportamento esperado e documentado.

### Ghost: frontend vs. painel administrativo

O Ghost expõe dois contextos distintos:

- **`https://localhost`** — o blog público. É o que os leitores veem. Possui um portal de assinatura por e-mail (magic link) que **não funciona em ambiente local** por não haver servidor SMTP configurado — comportamento esperado e fora do escopo deste desafio.
- **`https://localhost/ghost`** — o painel administrativo. É onde posts são criados e o blog é gerenciado. Na primeira visita, um wizard solicita nome, e-mail e senha para criar a conta de admin. O login subsequente usa e-mail + senha diretamente, **sem dependência de e-mail ou SMTP**.

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

---

## Certificado SSL

O certificado autoassinado é **gerado automaticamente** na primeira subida do container Nginx — o `docker-entrypoint.sh` executa o comando abaixo se `cert.pem` ainda não existir:

```bash
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/certs/key.pem \
    -out /etc/nginx/certs/cert.pem \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=BSATech/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

Os arquivos gerados ficam em `nginx/certs/` (montado via bind mount, listado no `.gitignore`).

> O navegador exibirá aviso de certificado autoassinado — clique em "Avançado → Prosseguir". Comportamento esperado e documentado.

---

## Backup e Restore do Banco de Dados

### Fazer backup

```bash
./scripts/backup.sh
```

Cria o arquivo `backups/backup-YYYY-MM-DD-HHMMSS.sql.gz` com dump completo do banco Ghost.

### Restaurar a partir de um backup

```bash
./scripts/restore.sh backups/backup-2026-06-05-103000.sql.gz
```

O script aceita caminhos relativos (a partir da raiz do projeto) ou absolutos.

### Teste completo de backup e restore

**1. Crie um post de teste no Ghost Admin**

Acesse `https://localhost/ghost`, faça login e publique um post com título reconhecível (ex: _"Post de teste backup"_).

**2. Faça o backup**

```bash
./scripts/backup.sh
# Saída: Backup created: ./backups/backup-YYYY-MM-DD-HHMMSS.sql.gz
```

**3. Simule perda de dados — drope e recrie o banco**

```bash
source .env
docker compose exec mysql mysql \
  -uroot -p"$MYSQL_ROOT_PASSWORD" \
  -e "DROP DATABASE $MYSQL_DATABASE; CREATE DATABASE $MYSQL_DATABASE;"
```

> Após este passo, acessar o Ghost retornará erro — banco vazio.

**4. Restaure o backup**

```bash
./scripts/restore.sh backups/backup-YYYY-MM-DD-HHMMSS.sql.gz
# Saída: Restore complete.
```

**5. Reinicie o Ghost para reconectar ao banco restaurado**

```bash
docker compose restart ghost
```

**6. Verifique**

Acesse `https://localhost` — o post criado no passo 1 deve estar presente.

---

## Monitoramento

| Serviço | URL | O que mostra |
|---|---|---|
| Prometheus | http://localhost:9090 | Métricas coletadas, targets, regras de alerta |
| Prometheus Targets | http://localhost:9090/targets | Status de cada scrape target |
| Prometheus Alerts | http://localhost:9090/alerts | Estado das regras (Inactive / Pending / Firing) |
| Grafana | http://localhost:3000 | Dashboards pré-configurados |
| AlertManager | http://localhost:9093 | Alertas ativos, silêncios, inibições |

**Credenciais Grafana:** `admin` / senha gerada pelo `setup-env.sh` (variável `GRAFANA_ADMIN_PASSWORD` no `.env`).

### Métricas coletadas

| Exporter | Target | Métricas |
|---|---|---|
| `node-exporter` | `node-exporter:9100` | CPU, memória, disco, rede do host |
| `cadvisor` | `cadvisor:8080` | CPU, memória e I/O por container |
| `mysql-exporter` | `mysql-exporter:9104` | Queries, conexões, status do MySQL |
| `prometheus` | `localhost:9090` | Próprias métricas do Prometheus |

### Dashboards pré-carregados no Grafana

Os dashboards são provisionados automaticamente via arquivos em `monitoring/grafana/` — nenhuma configuração manual necessária.

| Dashboard | ID Grafana.com | Fonte de métricas |
|---|---|---|
| Node Exporter Full | 1860 | node-exporter |
| MySQL Overview | 7362 | mysql-exporter |

---

## Alertas

### Regras configuradas

Definidas em `monitoring/prometheus/alerts/rules.yml`:

| Alerta | Condição | Período | Severidade |
|---|---|---|---|
| `DiskSpaceHigh` | Disco (real) > 80% | 1 min | warning |
| `ServiceDown` | Target Prometheus `up == 0` | 1 min | critical |
| `HighMemoryUsage` | Memória > 85% | 5 min | warning |
| `MySQLDown` | `mysql_up == 0` | 30s | critical |

> **AlertManager vazio = ambiente saudável.** Os alertas só aparecem lá quando disparados. Para ver as regras carregadas, acesse `http://localhost:9090/alerts`.

### Disparar alertas para validação

```bash
# Injeta DiskSpaceHigh via AlertManager API (ativo por 10 minutos)
./scripts/trigger-alerts.sh disk

# Para o MySQL — dispara MySQLDown em ~30s
./scripts/trigger-alerts.sh service mysql

# Para o mysql-exporter — dispara ServiceDown em ~1min
./scripts/trigger-alerts.sh service mysql-exporter

# Resolve o alerta de disco e reinicia serviços parados
./scripts/trigger-alerts.sh cleanup
```

**Serviços e os alertas que disparam quando parados:**

| Serviço | Alerta disparado | Tempo |
|---|---|---|
| `mysql` | `MySQLDown` | ~30s |
| `mysql-exporter` | `ServiceDown` | ~1min |
| `node-exporter` | `ServiceDown` | ~1min |
| `cadvisor` | `ServiceDown` | ~1min |
| `ghost`, `nginx`, `grafana` | Nenhum — não são scrape targets | — |

> O subcomando `disk` usa injeção via API porque encher um disco de 200+ GB até 80% seria impraticável. A API do AlertManager aceita alertas externos — o mesmo mecanismo que o Prometheus usa internamente. Ver `monitoring/prometheus/docs/alerting-flow.md` para detalhes.

---

## Smoke Tests

Valida o ambiente completo após `docker compose up`:

```bash
./scripts/test-environment.sh
```

**Checks executados:**

| # | Check | Como verifica |
|---|---|---|
| 1 | Ghost responde via HTTPS | `curl https://localhost` → 200 |
| 2 | Redirect HTTP → HTTPS | `curl http://localhost` → Location: https:// |
| 3 | Header HSTS presente | `Strict-Transport-Security` na resposta |
| 4 | Header X-Frame-Options presente | `X-Frame-Options` na resposta |
| 5 | Header X-Content-Type-Options presente | `X-Content-Type-Options` na resposta |
| 6 | MySQL healthcheck OK | `mysqladmin ping` dentro do container |
| 7 | Prometheus targets UP | API `/api/v1/targets` — todos com `health: up` |
| 8 | Grafana acessível | `GET /api/health` → 200 |
| 9 | Volume ghost_data existe | `docker volume inspect` |
| 10 | Volume mysql_data existe | `docker volume inspect` |

Saída com `✅ PASS` / `❌ FAIL` por check. Exit code `0` = tudo passou, `1` = alguma falha.

---

## Infraestrutura como Código — Terraform

A configuração dos secrets do repositório GitHub e do repositório no Docker Hub é **totalmente automatizada via Terraform**, eliminando qualquer passo manual de configuração de credenciais.

### O que o Terraform provisiona

```
Azure Key Vault  ──►  Terraform  ──►  Docker Hub: cria repositório + gera Access Token
                                  └──►  GitHub Actions Secrets: injeta DOCKERHUB_TOKEN,
                                                                DOCKERHUB_USERNAME,
                                                                DOCKERHUB_REPOSITORY
```

| Recurso | Provider | O que faz |
|---|---|---|
| `docker_hub_repository.this` | `docker/docker` | Cria o repositório `devpolatto/devops-challenge-nginx` no Docker Hub |
| `docker_access_token.ci_token` | `docker/docker` | Gera token de acesso com escopo `repo:read` + `repo:write` para o CI |
| `github_actions_secret.dockerhub_token` | `integrations/github` | Injeta o token gerado como secret `DOCKERHUB_TOKEN` no repositório |
| `github_actions_secret.dockerhub_username` | `integrations/github` | Injeta `DOCKERHUB_USERNAME` no repositório |
| `github_actions_secret.dockerhub_repository` | `integrations/github` | Injeta `DOCKERHUB_REPOSITORY` no repositório |

### Arquitetura de segredos

Nenhum segredo é hardcoded. O fluxo de autenticação é:

1. **Azure Key Vault** armazena o Personal Access Token do GitHub
2. **Terraform** autentica no Key Vault via Azure AD (sem senha no código)
3. O token é recuperado em runtime como `data source` e usado para autenticar o provider GitHub
4. O **state** do Terraform é armazenado em **Azure Blob Storage** — não localmente

```hcl
# O PAT do GitHub nunca toca o código — vem direto do Key Vault
data "azurerm_key_vault_secret" "github_access_token" {
  name         = local.azure_env.secrets.github_access_token
  key_vault_id = data.azurerm_key_vault.kv.id
}
```

### Como aplicar

```bash
cd infra/

# Inicializar backend remoto (Azure Blob Storage)
RESOURCE_GROUP=""
STORAGE_ACCOUNT=""
PROD_CONTAINER=""

terraform init --reconfigure \
  -backend-config="resource_group_name=$RESOURCE_GROUP" \
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" \
  -backend-config="container_name=$DEV_CONTAINER"'

# Revisar o plano
terraform plan -var-file="environments/prod.tfvars"

# Aplicar
terraform apply -var-file="environments/prod.tfvars"
```

> **Pré-requisito:** autenticação no Azure CLI (`az login`) com permissão de leitura no Key Vault configurado em `locals.tf`.

---

## CI Pipeline

### PR Title Check

Workflow: `.github/workflows/pr-title-check.yml`

Valida o título de todo Pull Request contra o padrão **Conventional Commits**:

```
<tipo>(<escopo opcional>): <descrição>
```

**Tipos aceitos:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`, `build`, `revert`

| Título | Resultado |
|---|---|
| `feat: add prometheus monitoring` | ✅ Passa |
| `fix(nginx): correct SSL cipher` | ✅ Passa |
| `Fix bug` | ❌ Falha — sem prefixo semântico |
| `update stuff` | ❌ Falha — sem prefixo semântico |

### Docker Publish

Workflow: `.github/workflows/docker-publish.yml`

Faz build e push da imagem Nginx automaticamente a cada push em `master` que altere arquivos em `nginx/`. Ver seção [Imagem Docker Custom](#imagem-docker-custom----devpolattodedevops-challenge-nginx) para detalhes.
