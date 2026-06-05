# Prometheus MCP Server — Setup com Docker

Instruções para rodar o [prometheus-mcp-server](https://github.com/tjhop/prometheus-mcp-server) via Docker integrado ao Claude Code, consultando o Prometheus do projeto.

> O Prometheus está acessível em `http://localhost:9090` (porta exposta no host via `docker-compose.yml`).

---

## Configuração no `.mcp.json`

O arquivo `.mcp.json` na raiz do projeto já contém a configuração pronta:

```json
{
  "mcpServers": {
    "prometheus": {
      "type": "stdio",
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "--network=host",
        "-e", "PROMETHEUS_MCP_SERVER_PROMETHEUS_URL=http://localhost:9090",
        "ghcr.io/tjhop/prometheus-mcp-server:latest"
      ],
      "env": {
        "PROMETHEUS_MCP_SERVER_WEB_LISTEN_ADDRESS": ":8181"
      }
    }
  }
}
```

### Por que `--network=host`?

O Prometheus está exposto na porta `9090` do host, não dentro de uma rede Docker compartilhada com o container do MCP server. O `--network=host` é a solução mais simples para alcançá-lo.

### Por que `PROMETHEUS_MCP_SERVER_WEB_LISTEN_ADDRESS=:8181`?

O servidor sobe um webserver interno de métricas (padrão `:8080`). Como o container do **cAdvisor** já ocupa a porta `8080`, é necessário redirecionar para uma porta livre — neste caso `:8181`.

---

## Testar manualmente

Para validar a conexão antes de usar no Claude Code:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
  | docker run --rm -i --network=host \
    -e PROMETHEUS_MCP_SERVER_PROMETHEUS_URL=http://localhost:9090 \
    -e PROMETHEUS_MCP_SERVER_WEB_LISTEN_ADDRESS=:8181 \
    ghcr.io/tjhop/prometheus-mcp-server:latest
```

---

## Verificar conexão no Claude Code

Dentro de uma sessão do Claude Code, use `/mcp` para listar e reconectar servidores MCP registrados.
