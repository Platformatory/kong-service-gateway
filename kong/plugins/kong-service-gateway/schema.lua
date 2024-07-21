local typedefs = require "kong.db.schema.typedefs"

local function validate_function(value)
  local func, err = load("return " .. value)
  if not func then
    return false, "invalid function: " .. err
  end
  return true
end

local function validate_lookup_table(value)
  if type(value) ~= "table" then
    return false, "lookup_table must be a table"
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
            inventory = {
              type = "record",
              fields = {
                {
                  kafka = {
                    type = "array",
                    elements = {
                      type = "record",
                      fields = {
                        { name = { type = "string", required = true } },
                        {
                          connection = {
                            type = "record",
                            fields = {
                              { bootstrap_servers = { type = "string", required = true } },
                            },
                          },
                        },
                        {
                          tags = {
                            type = "record",
                            fields = {
                              { env = { type = "string" } },
                              { domain = { type = "string" } },
                            },
                          },
                        },
                        {
                          routing_rules = {
                            type = "array",
                            elements = {
                              type = "record",
                              fields = {
                                {
                                  predicates = {
                                    type = "array",
                                    elements = {
                                      type = "record",
                                      fields = {
                                        { part = { type = "string", required = true } },
                                        { expression = { type = "string", required = true } },
                                      },
                                    },
                                  },
                                },
                                {
                                  resolve_subject_by = {
                                    type = "record",
                                    fields = {
                                      { type = { type = "string", required = true, one_of = { "lookup", "transform" } } },
                                      { lookup_key_function = { type = "string", required = false, custom_validator = validate_function } },
                                      { lookup_table = { type = "map", keys = { type = "string" }, values = { type = "string" }, required = false, custom_validator = validate_lookup_table } },
                                      { transform_function = { type = "string", required = false, custom_validator = validate_function } },
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
                  {
                    configs = {
                      type = "map",
                      keys = { type = "string" },
                      values = {
                        type = "record",
                        fields = {
                          { value = { type = "string", required = true } },
                          { type = { type = "string", required = true, one_of = { "string", "number", "boolean" } } },
                        },
                      },
                    },
                  },
                  {
                    tags = {
                      type = "record",
                      fields = {
                        { priority = { type = "string" } },
                        { type = { type = "string" } },
                        { lang = { type = "string" } },
                      },
                    },
                  },
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
                  { consumer = { type = "string", required = true } },
                  { name = { type = "string", required = true } },
                  {
                    value = {
                      type = "map",
                      keys = { type = "string" },
                      values = { type = "string", referenceable = true },
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