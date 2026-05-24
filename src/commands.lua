local _, ns = ...

ns.Commands = {}

local function print_(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff7ec0eeCastHistory|r: " .. msg)
end

function ns.Commands:Register()
  SLASH_CASTHISTORY1 = "/casthistory"
  SLASH_CASTHISTORY2 = "/ct"
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
      ns.Tracker:Clear()
    elseif input == "debug on" then
      CastHistoryDB.debug = true; print_("debug logging ON")
    elseif input == "debug off" then
      CastHistoryDB.debug = false; print_("debug logging OFF")
    elseif input == "debug clear" then
      wipe(CastHistoryDB.log); print_("log cleared")
    elseif input == "debug dump" then
      print_("log has " .. #CastHistoryDB.log .. " entries (saved to SavedVariables on logout/reload)")
    else
      print_("commands: show, hide, toggle, clear, config (move via /editmode)")
    end
  end
end
