# Desafio Técnico - Desenvolvedor DevOps Pleno - BSA Tech

## Desafio (Orientação original)

### Objetivo

Criar um ambiente com docker-compose para executar um blog e seus serviços, funcional ao ser clonado e iniciado com docker compose up.

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