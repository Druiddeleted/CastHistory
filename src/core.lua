local addonName, ns = ...
ns.addonName = addonName

ns.frame = CreateFrame("Frame", "CHCoreFrame", UIParent)
ns.frame:RegisterEvent("ADDON_LOADED")
ns.frame:RegisterEvent("PLAYER_LOGIN")

ns.frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    ns.DB:Init()
  elseif event == "PLAYER_LOGIN" then
    ns.UI:Build()
    ns.Events:Register()
    ns.Options:Register()
    ns.Commands:Register()
    if ns.DB.profile.shown then
      ns.UI.frame:Show()
    end
  end
end)
