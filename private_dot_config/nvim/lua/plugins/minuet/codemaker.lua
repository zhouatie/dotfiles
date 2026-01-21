local codemaker = require("codemaker")

local function extract_codemaker_text(json)
  if type(json) ~= "table" then
    return nil
  end

  if type(json.code) == "table" then
    return table.concat(json.code, "\n")
  end

  if type(json.data) == "table" and type(json.data.code) == "table" then
    return table.concat(json.data.code, "\n")
  end

  return nil
end

return {
  name = "CodeMaker",
  api_key = function()
    return "TERM"
  end,
  end_point = "https://api-code-maker.nie.netease.com/api/v1/ai_lab/code_generate",
  model = "cloud-music",
  stream = true,
  optional = {
    n = 1,
    temperature = 0.7,
    top_p = 0.7,
    max_tokens = 100,
  },
  get_text_fn = {
    no_stream = extract_codemaker_text,
    stream = function(json)
      return extract_codemaker_text(json)
    end,
  },
  transform = {
    function(request)
      local headers = request.headers

      headers.Authorization = nil
      headers.Accept = "application/json, text/plain, */*"
      headers["Content-Type"] = "application/json"
      headers.Connection = "close"
      headers["Code-Generate-Model-Code"] = "cloud-music"
      headers["Codemaker-Version"] = "2.7.1"
      headers["Department-Code"] = "yinyueshiyebu-jishuzhongxin-zhongduanjishubu-zhuomiandaqianduanzu"
      headers.Ide = "nvim"
      headers["User-Agent"] = "nvim"

      local access_token = codemaker.current_token()

      if access_token ~= nil and access_token ~= "" then
        headers["X-Access-Token"] = access_token
      else
        headers["X-Access-Token"] = nil
      end

      headers["X-Auth-User"] = ""

      headers.Host = nil

      local body = request.body
      body.prompt_after = body.suffix or ""
      body.suffix = nil
      body.prompt = body.prompt or ""
      body.stream = nil
      body.model = nil
      body.lang = body.lang or vim.bo.filetype or "plaintext"

      return request
    end,
  },
}
