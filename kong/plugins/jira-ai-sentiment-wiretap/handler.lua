local cjson = require("cjson.safe").new()
local http = require "resty.http"
local mime = require("mime")

local JiraAISentimentWiretapHandler = {
  PRIORITY = 1000,
  VERSION = "0.1.0",
}

local function analyze_sentiment(text, plugin_conf)
  local httpc = http.new()
  local api_key = plugin_conf.openai_token

  local res, err = httpc:request_uri("https://api.openai.com/v1/completions", {
    method = "POST",
    body = cjson.encode({
      model = plugin_conf.llm_model,
      prompt = "Analyze the sentiment of the following text: '" .. text .. "' Respond back with a single word either Positive, Negative, Neutral or Ambivalent",
      max_tokens = 10
    }),
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
    },
  })

  if (plugin_conf.debug) then
    kong.log.inspect(res)
  end

  if not res then
    ngx.log(ngx.ERR, "Failed to request: ", err)
    return nil, err
  end

  local response_body = cjson.decode(res.body)
  local sentiment = response_body.choices[1].text:match("^%s*(.-)%s*$") -- trim whitespace
  return sentiment
end

local function createJiraTicket(text, sentiment, plugin_conf)

  local httpc = http.new()
  local credentials = plugin_conf.jira_username .. ":" .. plugin_conf.jira_token
  local priority = "Low"

  if string.lower(sentiment) == 'negative' then
    priority = "Highest"
  end
  if string.lower(sentiment) == 'neutral' then
    priority = "Medium"
  end
  if string.lower(sentiment) == 'ambivalent' then
    priority = "Low"
  end
  if string.lower(sentiment) == 'positive' then
    priority = "Lowest"
  end

  local body = cjson.encode({
    fields = {
      issuetype = {name = plugin_conf.jira_issue_type },
      priority = { name = priority },
      project = { key = plugin_conf.jira_project },
      summary = sentiment .. ": " .. text
    },
    update = {}
  })

  local res, err = httpc:request_uri("https://" .. plugin_conf.jira_cloud_domain .. ".atlassian.net/rest/api/3/issue", {
    method = "POST",
    body = body,
    headers = {
      ["Content-Type"] = "application/json",
      ["Accept"] = "application/json",
      ["Authorization"] = "Basic " .. mime.b64(credentials),
    },
  })

  if (plugin_conf.debug) then
    kong.log.inspect(res)
  end

  if not res then
    ngx.log(ngx.ERR, "Failed to request: ", err)
    return nil, err
  end
end

local function checkSentimentLevel(sentiment, plugin_conf)
  local sentiment_lower = string.lower(sentiment)

  if (plugin_conf.sentiment_trigger_level == 'negative' and sentiment_lower == 'negative') then
    return true
  elseif (plugin_conf.sentiment_trigger_level == 'neutral' and (sentiment_lower == 'negative' or sentiment_lower == 'neutral')) then
    return true
  elseif (plugin_conf.sentiment_trigger_level == 'ambivalent' and (sentiment_lower == 'negative' or sentiment_lower == 'neutral' or sentiment_lower == 'ambivalent')) then
    return true
  elseif (plugin_conf.sentiment_trigger_level == 'positive') then
    return true
  else
    return false
  end
end

function JiraAISentimentWiretapHandler:access(plugin_conf)

  local body = cjson.decode(kong.request.get_raw_body())

  local sentiment = analyze_sentiment(body.text, plugin_conf)

  if (plugin_conf.debug) then
    kong.log.inspect("Sentiment level: " .. sentiment)
  end

  if (checkSentimentLevel(sentiment, plugin_conf)) then
    createJiraTicket(body.text, sentiment, plugin_conf)
  end

  kong.response.set_header("Sentiment", sentiment)
end

return JiraAISentimentWiretapHandler
