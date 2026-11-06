local KontraID = 87204735676240

local URLs = {
    ImGui = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/imgui.lua",
    Kontra = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/refs/heads/main/kontra.lua",
    Universal = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/universal.lua"
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
