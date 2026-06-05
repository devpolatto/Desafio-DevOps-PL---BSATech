# Fluxo de Alertas — Prometheus + AlertManager

## Como funciona

```
Prometheus (localhost:9090)
  └─ avalia rules.yml a cada 15s
      └─ condição violada por N minutos → status "Firing"
          └─ envia alerta para AlertManager (alertmanager:9093)
                  └─ AlertManager agrupa, roteia, silencia ou inibe
                          └─ dispara receiver (e-mail, Slack, webhook, log...)
```

## Onde ver o quê

| O que verificar | Onde | URL |
|---|---|---|
| Regras carregadas e seus status | Prometheus UI → Alerts | `http://localhost:9090/alerts` |
| Targets sendo coletados | Prometheus UI → Targets | `http://localhost:9090/targets` |
| Alertas atualmente disparando | AlertManager UI | `http://localhost:9093` |
| Silêncios e inibições ativas | AlertManager UI → Silences | `http://localhost:9093/#/silences` |

## Status possíveis de uma regra (Prometheus)

| Status | Significado |
|---|---|
| **Inactive** | Condição não violada — ambiente saudável |
| **Pending** | Condição violada, mas ainda dentro do período `for:` |
| **Firing** | Condição violada além do período `for:` — alerta enviado ao AlertManager |

## Por que o AlertManager aparece vazio?

AlertManager só exibe alertas **ativos no momento**. Se nenhuma condição está violada, a lista fica vazia — isso é o comportamento correto e esperado de um ambiente saudável.

Para confirmar que as regras foram carregadas corretamente pelo Prometheus:

```bash
# Lista os nomes das regras carregadas
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[].name'

# Saída esperada:
# "DiskSpaceHigh"
# "ServiceDown"
# "HighMemoryUsage"
# "MySQLDown"
```

## Regras configuradas neste projeto

Definidas em `monitoring/prometheus/alerts/rules.yml`:

| Alerta | Condição | Período | Severidade |
|---|---|---|---|
| `DiskSpaceHigh` | Disco (real) > 80% | 1 min | warning |
| `ServiceDown` | Target Prometheus `up == 0` | 1 min | critical |
| `HighMemoryUsage` | Memória > 85% | 5 min | warning |
| `MySQLDown` | `mysql_up == 0` | 30s | critical |

## Forçar disparo para validação

Use o script `scripts/trigger-alerts.sh` para forçar condições de alerta de forma controlada:

```bash
# Injeta o alerta DiskSpaceHigh via AlertManager API
./scripts/trigger-alerts.sh disk

# Para um serviço para disparar ServiceDown / MySQLDown
./scripts/trigger-alerts.sh service mysql

# Resolve o alerta de disco e reinicia serviços parados
./scripts/trigger-alerts.sh cleanup
```

Após `service`, aguarde o período `for:` da regra (~1 min) e verifique em `http://localhost:9093`.

---

## Decisão de design: por que o subcomando `disk` usa injeção via API

### O problema

O alerta `DiskSpaceHigh` avalia a métrica `node_filesystem_avail_bytes` coletada pelo `node-exporter` do host. Para disparar a condição real (uso > 80%), seria necessário preencher o disco fisicamente com um arquivo temporário via `dd`.

Em ambientes de desenvolvimento típicos — máquinas com discos de 200 GB+ —, isso é inviável:

```
Disco total:  233 GB
Uso atual:     30 GB (13%)
Para atingir 80%: ~172 GB a escrever
```

Escrever 172 GB causaria impacto real no ambiente (lentidão, risco de travar o SO) e tornaria o teste destrutivo em vez de controlado.

### A solução: AlertManager API

O AlertManager expõe uma API REST (`POST /api/v2/alerts`) que aceita alertas externos — o mesmo endpoint que o Prometheus usa para enviar alertas ao roteador. Injetar um alerta diretamente nesse endpoint é equivalente ao Prometheus tê-lo disparado.

```bash
curl -X POST http://localhost:9093/api/v2/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": { "alertname": "DiskSpaceHigh", "severity": "warning", ... },
    "annotations": { "description": "Disk usage is 85.0% on / (simulated)" },
    "endsAt": "<timestamp + 10min>"
  }]'
```

O alerta aparece no AlertManager UI, passa pelo roteamento, respeita silêncios e inibições — **o comportamento é idêntico ao de um alerta real**, exceto pela origem (API em vez de Prometheus).

### Por que esta abordagem é válida em produção

A injeção via API não é apenas um workaround de demo. Ela é usada em cenários reais:

- **Testes de integração de alerting:** validar que o roteamento, silêncios e receivers estão configurados corretamente sem precisar reproduzir a condição de falha.
- **Simulações de incidente:** treinar runbooks e on-call sem derrubar infraestrutura real.
- **Alertas de fontes externas:** sistemas legados ou scripts de monitoramento que não expõem métricas Prometheus podem enviar alertas diretamente ao AlertManager.

### Cleanup

O alerta é resolvido re-postando com `endsAt` no passado, o que instrui o AlertManager a marcá-lo como resolvido imediatamente:

```bash
./scripts/trigger-alerts.sh cleanup
```
