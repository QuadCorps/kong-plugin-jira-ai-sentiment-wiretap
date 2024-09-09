local typedefs = require "kong.db.schema.typedefs"


local PLUGIN_NAME = "jira-ai-sentiment-wiretap"


local schema = {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { llm_model = { type = "string", description = "OpenAI model to use to determine sentiment", required = true, default = "gpt-3.5-turbo-instruct" } },
          { openai_token = { type = "string", description = "OpenAI Auth Token", required = true } },
          { jira_token = { type = "string", description = "JIRA Cloud Auth Token", required = true } },
          { jira_username = { type = "string", description = "JIRA Cloud username", required = true } },
          { jira_cloud_domain = { type = "string", description = "Your JIRA Cloud company sub domain i.e. <domain>.atlassian.net", required = true } },
          { jira_project = { type = "string", description = "JIRA Cloud project to create tickets", required = true } },
          { jira_issue_type = { type = "string", description = "The issue type to create", required = true, default = "Task",
                                        one_of = { "Task", "Bug", "Story", "Epic" } } },
          { sentiment_trigger_level = { type = "string", description = "The sentiment level you wish wiretap to trigger", required = true, default = "negative",
                                one_of = { "negative", "neutral", "ambivalent", "positive" } } },
          { debug = { type = "boolean", description = "Debug level for API calls", required = true }}
        },
      },
    },
  },
}

return schema
