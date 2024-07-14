local cjson = require "cjson"
local kong = kong

local function is_valid_json(value)
  local success, _ = pcall(cjson.decode, value)
  return success
end

local function get_consumer()
  local consumer = kong.client.get_consumer()
  if not consumer then
    return nil, "Unauthenticated"
  end
  return consumer
end

local function find_kafka_cluster(clusters, domain)
  for _, cluster in ipairs(clusters) do
    if cluster.domain == domain then
      return cluster.bootstrap_servers
    end
  end
  return nil, "Cluster not found"
end

local function find_channel(channels, channel_name)
  for _, channel in ipairs(channels) do
    if channel.resolve_by == "key_lookup" then
      local lookup = cjson.decode(channel.value)
      if lookup[channel_name] then
        return lookup[channel_name]
      end
    elseif channel.resolve_by == "regex" then
      local match = ngx.re.match(channel_name, channel.value)
      if match then
        return match
      end
    end
  end
  return nil, "Channel not found"
end

local function find_configuration_profile(profiles, profile_name)
  for _, profile in ipairs(profiles) do
    if profile.name == profile_name then
      return profile.kafka_configurations
    end
  end
  return nil, "Configuration profile not found"
end

local function find_credential(credentials, consumer_name)
  for _, cred in ipairs(credentials) do
    if cred.consumer_match_type == "LITERAL" and cred.consumer_match_value == consumer_name then
      if cred.provider == "literal" then
        return cred.value
      elseif cred.provider == "env" then
        return os.getenv(cred.value)
      elseif cred.provider == "JSON_MAP" and is_valid_json(cred.value) then
        return cjson.decode(cred.value)
      end
    elseif cred.consumer_match_type == "REGEX" then
      local match = ngx.re.match(consumer_name, cred.consumer_match_value)
      if match then
        if cred.provider == "literal" then
          return cred.value
        elseif cred.provider == "env" then
          return os.getenv(cred.value)
        elseif cred.provider == "JSON_MAP" and is_valid_json(cred.value) then
          return cjson.decode(cred.value)
        end
      end
    end
  end
  return nil, "Credential not found"
end

local KongServiceGateway = {}

KongServiceGateway.VERSION = "1.0.0"
KongServiceGateway.PRIORITY = 1000


function KongServiceGateway:access(config)

  local consumer, err = get_consumer()
  if not consumer then
    return kong.response.exit(401, { message = err })
  end

  local path = kong.request.get_path()
  local subpath = string.match(path, "/([^/]+)$")

  if subpath == "kafka_clusters" then
    local domain = kong.request.get_query()["domain"]
    if not domain then
      return kong.response.exit(400, { message = "Domain query parameter is required" })
    end
    local result, err = find_kafka_cluster(config.entities.kafka_clusters, domain)
    if not result then
      return kong.response.exit(404, { message = err })
    end
    return kong.response.exit(200, { bootstrap_servers = result })
  elseif subpath == "channels" then
    local channel_name = kong.request.get_query()["channel_name"]
    if not channel_name then
      return kong.response.exit(400, { message = "Channel name query parameter is required" })
    end
    local result, err = find_channel(config.entities.channels, channel_name)
    if not result then
      return kong.response.exit(404, { message = err })
    end
    return kong.response.exit(200, { resolved_value = result })
  elseif subpath == "configuration_profiles" then
    local profile_name = kong.request.get_query()["profile_name"]
    if not profile_name then
      return kong.response.exit(400, { message = "Profile name query parameter is required" })
    end
    local result, err = find_configuration_profile(config.entities.configuration_profiles, profile_name)
    if not result then
      return kong.response.exit(404, { message = err })
    end
    return kong.response.exit(200, { kafka_configurations = result })
  elseif subpath == "credentials" then
    local consumer_name = consumer.username or consumer.custom_id
    local result, err = find_credential(config.entities.credentials, consumer_name)
    if not result then
      return kong.response.exit(404, { message = err })
    end
    return kong.response.exit(200, { credential_value = result })
  else
    return kong.response.exit(404, { message = "Invalid subpath" })
  end
end

return KongServiceGateway

