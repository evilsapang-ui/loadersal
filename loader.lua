local KontraID = 87204735676240
local timestamp = "?t=" .. tostring(os.time()) -- bypasses GitHub cache

local URLs = {
    ImGui = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/imgui.lua" .. timestamp,
    Kontra = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/kontra.lua" .. timestamp,
    Universal = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/universal.lua" .. timestamp
}

local function loadScript(url)
    local success, code = pcall(game.HttpGet, game, url)
    if success and code then
        local func, err = loadstring(code)
        if func then
            func()
        else
            warn("Syntax error: " .. tostring(err))
        end
    else
        warn("Failed to download: " .. url)
    end
end

if game.PlaceId == KontraID then
    print("[Loader] Kontra detected. Loading modules...")
    loadScript(URLs.Kontra)
else
    print("[Loader] Universal game detected. Loading modules...")
    loadScript(URLs.Universal)
end
