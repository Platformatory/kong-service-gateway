package = "kong-service-gateway"

version = "1.0.0-1"

supported_platforms = {"linux"}

source = {
  url = "git+https://github.com/Platformatory/kong-service-gateway.git",
  tag = "main"
}

description = {
  summary = "Provides a service catalog to help resolve channels.",
  license = "MIT",
  maintainer = "Pavan Keshavamurthy <pavan@platformatory.com>"
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.kong-service-gateway.handler"] = "kong/plugins/kong-service-gateway/handler.lua",
    ["kong.plugins.kong-service-gateway.schema"] = "kong/plugins/kong-service-gateway/schema.lua",
  }
}
