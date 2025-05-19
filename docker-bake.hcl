// docker-bake.hcl
group "default" {
  targets = ["otelless-vllm"]
}

target "otelless-vllm" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["otelless-vllm:0.8.5.post1"]
  output = ["type=docker"]
  
  // Resource limits
  args = {
    DOCKER_BUILDKIT_MEMORY = "90g"
    DOCKER_BUILDKIT_SWAP = "-1"
  }
} 