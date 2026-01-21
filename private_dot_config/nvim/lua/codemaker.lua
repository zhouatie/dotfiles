local curl_ok, curl = pcall(require, "plenary.curl")
local random_seeded = false

local M = {
  base_url = "https://api-code-maker.nie.netease.com",
  default_headers = {
    Accept = "application/json, text/plain, */*",
    ["Codemaker-Version"] = "2.7.1",
    Connection = "close",
    Ide = "vscode",
    ["User-Agent"] = "axios/1.11.0",
  },
  token = nil,
  auth_key = nil,
  proxy = vim.env.CODEMAKER_PROXY,
}

local function ensure_curl()
  if not curl_ok then
    curl_ok, curl = pcall(require, "plenary.curl")
  end

  return curl_ok
end

local function ensure_random_seed()
  if random_seeded then
    return
  end

  local seed = vim.loop.hrtime() % 0x7fffffff
  math.randomseed(seed)
  math.random()
  math.random()
  math.random()
  random_seeded = true
end

local function json_decode_safe(payload)
  if type(payload) ~= "string" or payload == "" then
    return nil
  end

  local decode = vim.json and vim.json.decode or vim.fn.json_decode
  local ok, result = pcall(decode, payload)
  if not ok then
    return nil
  end

  return result
end

local function json_encode_safe(payload)
  if type(payload) ~= "table" then
    return payload
  end

  local encode = vim.json and vim.json.encode or vim.fn.json_encode
  local ok, result = pcall(encode, payload)
  if not ok then
    return nil
  end

  return result
end

local function generate_trace_id()
  ensure_random_seed()

  local parts = {}
  for index = 1, 16 do
    parts[index] = string.format("%x", math.random(0, 15))
  end

  local id = table.concat(parts)
  return string.format("%s:%s:0:1", id, id)
end

M.token = vim.env.CODEMAKER_ACCESS_TOKEN and vim.env.CODEMAKER_ACCESS_TOKEN ~= "" and vim.env.CODEMAKER_ACCESS_TOKEN
  or M.bootstrap_token

function M.current_token()
  local env_token = vim.env.CODEMAKER_ACCESS_TOKEN
  if env_token and env_token ~= "" then
    return env_token
  end

  if M.token and M.token ~= "" then
    return M.token
  end

  if M.bootstrap_token and M.bootstrap_token ~= "" then
    return M.bootstrap_token
  end

  return nil
end

function M.request(method, path, opts)
  if not ensure_curl() then
    return nil, "plenary.curl is required"
  end

  opts = opts or {}
  local headers = vim.tbl_extend("force", {}, M.default_headers)
  if type(opts.headers) == "table" then
    for key, value in pairs(opts.headers) do
      headers[key] = value
    end
  end

  headers["Ntes-Trace-Id"] = headers["Ntes-Trace-Id"] or generate_trace_id()

  local body = opts.body
  if type(body) == "table" then
    headers["Content-Type"] = headers["Content-Type"] or "application/json"
    body = json_encode_safe(body)
    if body == nil then
      return nil, "failed to encode request body"
    end
  end

  local request_options = {
    method = string.upper(method),
    url = M.base_url .. path,
    headers = headers,
    body = body,
    timeout = opts.timeout or 10000,
    proxy = opts.proxy or M.proxy,
    insecure = opts.insecure,
    result = true,
  }

  local ok, response = pcall(curl.request, request_options)
  if not ok then
    return nil, response
  end

  if not response then
    return nil, "empty response"
  end

  if response.exit and response.exit ~= 0 then
    return nil, response.stderr or string.format("curl exit %s", response.exit)
  end

  if not response.status or response.status >= 400 then
    return nil, string.format("HTTP %s", response.status or "unknown")
  end

  local decoded = json_decode_safe(response.body)
  if not decoded then
    return nil, "failed to decode response"
  end

  return decoded
end

function M.fetch_auth_key(token)
  if token == nil or token == "" then
    return nil, "missing access token"
  end

  local payload, err = M.request("get", "/get_auth_key", {
    headers = {
      ["X-Access-Token"] = token,
    },
  })

  if not payload or type(payload.auth_key) ~= "string" or payload.auth_key == "" then
    return nil, err or "invalid auth_key response"
  end

  M.auth_key = payload.auth_key

  return payload.auth_key
end

function M.renew_token(auth_key, user, ttl)
  if auth_key == nil or auth_key == "" then
    return nil, "missing auth_key"
  end

  local body = {
    key = auth_key,
    ttl = ttl or 86400,
    user = user,
  }

  local payload, err = M.request("post", "/renew_token", {
    body = body,
  })

  if not payload then
    return nil, err or "invalid renew response"
  end

  local new_token = payload.access_token or payload.token
  if type(payload.data) == "table" then
    new_token = new_token or payload.data.access_token or payload.data.token
  end

  if type(new_token) ~= "string" or new_token == "" then
    return nil, "missing token in response"
  end

  return new_token
end

function M.refresh()
  -- local base_token = M.current_token()
  local user = vim.env.USER or ""

  -- local auth_key, auth_err = M.fetch_auth_key(base_token)
  -- if not auth_key then
  --   return nil, auth_err
  -- end
  local auth_key =
    "dc0a510aebeda4989ce120bd31ba931a40904e8d41b1c3a01e05c5ef2c1dc302f97e3a817bf52d7cf8610d3c8d6a6adab89b8c704c5a997746ee175a95a2bc43"

  local new_token, renew_err = M.renew_token(auth_key, user)
  if not new_token then
    return nil, renew_err
  end

  M.token = new_token
  vim.env.CODEMAKER_ACCESS_TOKEN = new_token

  return new_token
end

M.ensure_curl = ensure_curl

return M
