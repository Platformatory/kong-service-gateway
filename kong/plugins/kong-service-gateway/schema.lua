local typedefs = require "kong.db.schema.typedefs"

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
                        { connection = {
                            type = "record",
                            fields = {
                              { bootstrap_servers = { type = "string", required = true } },
                            },
                          },
                        },
                        { tags = {
                            type = "map",
                            keys = { type = "string" },
                            values = { type = "string" },
                            required = false,
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
                                      { lookup_key_function = { type = "string", required = false } },
                                      { lookup_table = {
                                          type = "map",
                                          keys = { type = "string" },
                                          values = { type = "string" },
                                          required = false,
                                        },
                                      },
                                      { transform_function = { type = "string", required = false } },
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
                  { kafka_configurations = {
                      type = "map",
                      keys = { type = "string" },
                      values = { type = "string" },
                      required = true,
                    },
                  },
                  { tags = {
                      type = "map",
                      keys = { type = "string" },
                      values = { type = "string" },
                      required = false,
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
                  { provider = { type = "string", required = true } },
                  { value = {
                      type = "map",
                      keys = { type = "string" },
                      values = { type = "string" },
                      required = true,
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