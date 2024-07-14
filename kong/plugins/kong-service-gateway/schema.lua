local plugin_name = ({ ... })[1]:match("^kong%.plugins%.([^%.]+)")
local typedefs = require "kong.db.schema.typedefs"

local typedefs = require "kong.db.schema.typedefs"
local cjson = require "cjson"

-- Function to check if a string is a valid JSON
local function is_valid_json(value)
  local success, _ = pcall(function() cjson.decode(value) end)
  return success
end

-- Custom validator for the `value` field in channels
local function validate_channel_value(value, config)
  if config.resolve_by == "key_lookup" then
    return is_valid_json(value)
  end
  return true
end

return {
  name = "kong-service-gateway",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          {
            entities = {
              type = "record",
              fields = {
                {
                  kafka_clusters = {
                    type = "array",
                    elements = {
                      type = "record",
                      fields = {
                        { name = { type = "string", required = true } },
                        { domain = { type = "string", required = true } },
                        { tags = { type = "string", required = false } },
                        { bootstrap_servers = { type = "string", required = true } },
                      },
                    },
                  },
                },
                {
                  channels = {
                    type = "array",
                    elements = {
                      type = "record",
                      fields = {
                        { name = { type = "string", required = true } },
                        { resolve_by = { type = "string", one_of = { "key_lookup", "regex" }, required = true } },
                        { value = {
                            type = "string",
                            required = true,
                            custom_validator = function(value, config, dao, context)
                              if context and context.resolve_by == "key_lookup" then
                                return is_valid_json(value)
                              end
                              return true
                            end,
                        }},
                      },
                    },
                  },
                },
                {
                  configuration_profiles = {
                    type = "array",
                    elements = {
                      type = "record",
                      fields = {
                        { name = { type = "string", required = true } },
                        { kafka_configurations = {
                            type = "string",
                            required = true,
                            custom_validator = is_valid_json,
                        }},
                        { tags = { type = "string", required = false } },
                      },
                    },
                  },
                },
                {
                  credentials = {
                    type = "array",
                    elements = {
                      type = "record",
                      fields = {
                        { name = { type = "string", required = true } },
                        { consumer_match_type = { type = "string", one_of = { "LITERAL", "REGEX" }, required = true } },
                        { consumer_match_value = { type = "string", required = true } },
                        { provider = { type = "string", one_of = { "JSON_MAP" }, required = true } },
                        { value = {
                            type = "string",
                            required = true,
                            custom_validator = is_valid_json,
                        }},
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
}

