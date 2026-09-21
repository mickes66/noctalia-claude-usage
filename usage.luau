--!nonstrict
-- Bar icon for Claude Code usage. Reads the JSON record that Omarchy's
-- omarchy-agent-usage-update already maintains, so both shells show the same
-- numbers instead of two separate collectors drifting apart.
--
-- Left click: notify with a quick summary. Right click: open a new Claude
-- Code session in a terminal (mirrors omarchy.agents' own right-click).

local USAGE_FILE = "~/.local/state/omarchy/agents/usage/claude.json"
local REFRESH_MS = 60000

local data = nil

local function pct(limit)
  return math.floor((limit.percent or 0) * 100)
end

-- Days since 1970-01-01 for a proleptic Gregorian y/m/d (Howard Hinnant's
-- civil_from_days, reversed) - avoids relying on os.time's local-timezone
-- assumptions for what Anthropic's API always sends as UTC.
local function daysFromCivil(y, m, d)
  y = (m <= 2) and (y - 1) or y
  local era = ((y >= 0) and y or (y - 399)) // 400
  local yoe = y - era * 400
  local doy = (153 * ((m > 2) and (m - 3) or (m + 9)) + 2) // 5 + d - 1
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
  return era * 146097 + doe - 719468
end

local function parseIsoUtcSeconds(iso)
  if type(iso) ~= "string" then
    return nil
  end
  local y, mo, d, h, mi, se = iso:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if y == nil then
    return nil
  end
  local days = daysFromCivil(tonumber(y), tonumber(mo), tonumber(d))
  return days * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(se)
end

-- Short "in Xh Ym" / "in Ym" relative label instead of the raw ISO timestamp,
-- which was too wide for the tooltip.
local function relativeLabel(iso)
  local epoch = parseIsoUtcSeconds(iso)
  if epoch == nil then
    return "?"
  end
  local diff = epoch - math.floor(noctalia.nowMs() / 1000)
  if diff <= 0 then
    return "now"
  end
  local hours = diff // 3600
  local minutes = (diff % 3600) // 60
  if hours > 0 then
    return `in {hours}h {minutes}m`
  end
  return `in {minutes}m`
end

-- Fixed-width row labels: "Session"/"Weekly" differ by one character, which
-- shifts the value column since the tooltip doesn't align key/value pairs
-- across rows. Same-length labels keep both value columns lined up.
local WINDOW_LABELS = { "5h limit", "7d limit" }

local function shortLabel(label)
  if type(label) ~= "string" then
    return "?"
  end
  return label:match("^(.-)%s*%(") or label
end

local function summaryText()
  if data == nil or data.limits == nil or #data.limits == 0 then
    return "…"
  end
  return `{pct(data.limits[1])}%`
end

local function render()
  barWidget.setImage("claude.svg", false, 16, 16)
  barWidget.setText(summaryText())

  if data == nil then
    barWidget.setTooltip("Claude Code — loading…")
    return
  end

  local rows = { { key = "Tier", value = data.tierLabel or "—" } }
  for i, limit in ipairs(data.limits or {}) do
    local label = WINDOW_LABELS[i] or shortLabel(limit.label)
    table.insert(rows, { key = label, value = `{pct(limit)}% (resets {relativeLabel(limit.resetsAt)})` })
  end
  table.insert(rows, {
    key = "Today",
    value = `{data.todayPrompts or 0} prompts · {data.todaySessions or 0} sessions`,
  })
  barWidget.setTooltip(rows)
end

local function refresh()
  noctalia.runAsync("omarchy-agent-usage-update claude", function()
    local contents = noctalia.readFile(USAGE_FILE)
    if contents ~= nil then
      local ok, decoded = pcall(function()
        return noctalia.json.decode(contents)
      end)
      if ok and decoded ~= nil then
        data = decoded
      end
    end
    render()
  end, 10000)
end

function update()
  noctalia.setUpdateInterval(REFRESH_MS)
  refresh()
end

function onClick()
  render()
  if data ~= nil and data.limits ~= nil and #data.limits > 0 then
    local session = `Session {pct(data.limits[1])}%`
    local weekly = data.limits[2] ~= nil and ` · Weekly {pct(data.limits[2])}%` or ""
    noctalia.notify("Claude Code", session .. weekly)
  else
    noctalia.notify("Claude Code", "No usage data yet")
  end
end

function onRightClick()
  noctalia.runInTerminal("claude --permission-mode auto")
end
