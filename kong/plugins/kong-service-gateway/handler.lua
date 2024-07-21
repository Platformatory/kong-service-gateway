local url = require "socket.url"

local function get_consumer()
  local consumer = kong.client.get_consumer()
  if not consumer then
    return nil, "Unauthenticated"
  end
  return consumer
end

local function parse_channel_url(channel_url)
  local parsed_url = url.parse(channel_url)
  if not parsed_url then
    return nil, "Invalid channel URL"
  end
  local uri = {
    scheme = parsed_url.scheme,
    host = parsed_url.host,
    path = {},
    query = parsed_url.query and ngx.decode_args(parsed_url.query) or nil
  }
  for segment in parsed_url.path:gmatch("[^/]+") do
    table.insert(uri.path, segment)
  end
  uri.raw_path = parsed_url.path
  return uri
end

local function match_expression(expression, value)
  return value:match(expression) ~= nil
end

local function match_predicates(predicates, uri)
  for _, predicate in ipairs(predicates) do
    local part = uri[predicate.part]
    if predicate.part == "path" and uri.raw_path then
      part = uri.raw_path
    end
    if type(part) == "table" then
      local matched = false
      for _, v in ipairs(part) do
        if match_expression(predicate.expression, v) then
          matched = true
          break
        end
      end
      if not matched then
        kong.log.debug("Predicate did not match: ", predicate.part, " value: ", table.concat(part, ", "), " expression: ", predicate.expression)
        return false
      end
    elseif type(part) == "string" then
      if not match_expression(predicate.expression, part) then
        kong.log.debug("Predicate did not match: ", predicate.part, " value: ", part, " expression: ", predicate.expression)
        return false
      end
    else
      kong.log.debug("Predicate did not match: ", predicate.part, " value: nil", " expression: ", predicate.expression)
      return false
    end
  end
  return true
end

local function resolve_channel_mappings(rule, uri)
  if rule.resolve_subject_by.type == "lookup" then
    local lookup_key_func = load("return " .. rule.resolve_subject_by.lookup_key_function)()
    local lookup_key = lookup_key_func(uri)
    return rule.resolve_subject_by.lookup_table[lookup_key]
  elseif rule.resolve_subject_by.type == "transform" then
    local transform_func = load("return " .. rule.resolve_subject_by.transform_function)()
    return transform_func(uri)
  end
end

local function find_routing_rule(routing_rules, uri)
  for _, rule in ipairs(routing_rules) do
    if match_predicates(rule.predicates, uri) then
      local channel_mapping = resolve_channel_mappings(rule, uri)
      return rule, channel_mapping
    end
  end
  return nil, nil, "No matching routing rule found"
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
    if cred.consumer == consumer_name then
      if cred.provider == "literal" then
        return cred.value
      elseif cred.provider == "env" then
        local transformed_value = {}
        for k, v in pairs(cred.value) do
          transformed_value[k] = os.getenv(v)
        end
        return transformed_value
      end
    end
  end
  return nil, "Credential not found"
end

local function merge_tables(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
  end
  return t1
end

local KongServiceGateway = {}

KongServiceGateway.VERSION = "1.0.0"
KongServiceGateway.PRIORITY = 1000

function KongServiceGateway:access(config)
  kong.log.debug("Entered access phase")
  kong.log.inspect(config)

  local consumer, err = get_consumer()
  if not consumer then
    kong.log.err("Consumer not found: ", err)
    return kong.response.exit(401, { message = err })
  end

  local query_params = kong.request.get_query()
  kong.log.inspect(query_params)
  local config_profile = query_params["config_profile"]
  local channel_url = query_params["channel"]

  if not config_profile or not channel_url then
    kong.log.err("config_profile or channel query parameters are missing")
    return kong.response.exit(400, { message = "config_profile and channel query parameters are required" })
  end

  local uri, err = parse_channel_url(channel_url)
  if not uri then
    kong.log.err("Invalid channel URL: ", err)
    return kong.response.exit(400, { message = err })
  end

  kong.log.inspect(uri)

  -- Iterate over each Kafka cluster
  for _, kafka_cluster in ipairs(config.inventory.kafka) do
    -- Check routing rules for this Kafka cluster
    local rule, channel_mapping, err = find_routing_rule(kafka_cluster.routing_rules, uri)
    if rule then
      -- We have a match, find the configuration profile
      local configuration_profile, err = find_configuration_profile(config.configuration_profiles, config_profile)
      if not configuration_profile then
        kong.log.err("Configuration profile not found: ", err)
        return kong.response.exit(404, { message = err })
      end

      -- Process the credentials
      local consumer_name = consumer.username or consumer.custom_id
      local credential, err = find_credential(config.credentials, consumer_name)
      if not credential then
        kong.log.err("Credential not found: ", err)
        return kong.response.exit(404, { message = err })
      end

      -- Merge configuration profile and credentials
      local merged_configuration = merge_tables(configuration_profile, credential)

      -- Prepare the response
      local response = merge_tables(kafka_cluster.connection, { channel_mapping = channel_mapping, configuration = merged_configuration })
      kong.log.inspect(response)
      return kong.response.exit(200, response)
    else
      kong.log.debug("No matching routing rule found for cluster: ", kafka_cluster.name, " with host: ", uri.host)
    end
  end

  kong.log.err("No matching routing rule found")
  return kong.response.exit(404, { message = "No matching routing rule found" })
end

return KongServiceGateway
