local _, ns = ...

ns.Commands = {}

local function print_(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff7ec0eeCastHistory|r: " .. msg)
end

function ns.Commands:Register()
  SLASH_CASTHISTORY1 = "/casthistory"
  SLASH_CASTHISTORY2 = "/ch"
  SlashCmdList["CASTHISTORY"] = function(input)
    input = (input or ""):lower():match("^%s*(.-)%s*$")
    if input == "" or input == "config" or input == "options" then
      ns.Options:Open()
    elseif input == "show" then
      ns.UI.frame:Show(); ns.DB.profile.shown = true
    elseif input == "hide" then
      ns.UI.frame:Hide(); ns.DB.profile.shown = false
    elseif input == "toggle" then
      ns.UI:Toggle()
    elseif input == "clear" then
      ns.Casts:Clear()
    elseif input == "debug on" then
      CastHistoryDB.debug = true; print_("debug logging ON")
    elseif input == "debug off" then
      CastHistoryDB.debug = false; print_("debug logging OFF")
    elseif input == "debug clear" then
      wipe(CastHistoryDB.log); print_("log cleared")
    elseif input == "replay" then
      -- Re-runs the recorded event log through the intake rules. The counts are
      -- the regression check: a rules change that eats real casts shows up as a
      -- spell whose cast count dropped against an earlier run.
      local lines, err, result = ns.Replay:Report()
      if err then
        print_(err)
      else
        print_(("replayed %d events -> %d casts (events -> casts)"):format(result.read, result.total))
        for _, line in ipairs(lines) do print_(line) end
      end
    elseif input == "probe" then
      local n, err = ns.Probe:Run()
      if err then
        print_(err)
      else
        print_(("probed %d spells — /reload, then read CastHistoryDB.probe"):format(n))
      end
    elseif input == "debug dump" then
      print_("log has " .. #CastHistoryDB.log .. " entries (saved to SavedVariables on logout/reload)")
    else
      print_("commands: show, hide, toggle, clear, config, replay, probe (move via /editmode)")
    end
  end
end
