resource "docker_hub_repository" "this" {
  name        = "devops-challenge-nginx"
  namespace   = "devpolatto"
  description = "Nginx image for DevOps Challenge"
  private     = false
}

resource "docker_access_token" "ci_token" {
  token_label = "terraform-github-actions"
  scopes      = ["repo:read", "repo:write"]
}

resource "github_actions_secret" "dockerhub_token" {
  repository  = data.github_repository.Desafio_DevOps.name
  secret_name = "DOCKERHUB_TOKEN"
  value       = docker_access_token.ci_token.token
}

resource "github_actions_secret" "dockerhub_username" {
  repository  = data.github_repository.Desafio_DevOps.name
  secret_name = "DOCKERHUB_USERNAME"
  value       = local.github.owner
}

resource "github_actions_secret" "dockerhub_repository" {
  repository  = data.github_repository.Desafio_DevOps.name
  secret_name = "DOCKERHUB_REPOSITORY"
  value       = docker_hub_repository.this.id
}