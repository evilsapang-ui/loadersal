-- Universal Loader
local KontraID = 87204735676240

-- REPLACE THESE URLS WITH YOUR RAW GITHUB LINKS
local URLs = {
    Kontra = "https://raw.githubusercontent.com/yourname/repo/main/kontra.lua",
    Universal = "https://raw.githubusercontent.com/yourname/repo/main/universal.lua"
}

local function load(url)
    local success, code = pcall(function()
        return game:HttpGet(url)
    end)
    if success and code then
        local func, err = loadstring(code)
        if func then
            func()
        else
            warn("Syntax error in loaded script: " .. tostring(err))
        end
    else
        warn("Failed to download script from: " .. url)
    end
end

if game.PlaceId == KontraID then
    print("[Loader] Kontra detected. Loading Kontra modules...")
    load(URLs.Kontra)
else
    print("[Loader] Universal game detected. Loading Universal modules...")
    load(URLs.Universal)
end
