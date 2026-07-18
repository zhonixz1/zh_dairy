-- config.lua
Config = Config or {}

Config.Cows = {
    [1] = {
        coords     = vector4(1395.544, 295.503, 88.303, 0.81),
        model      = `a_c_cow`,
        radius     = 120.0,
        milkTime   = 12000,
        rewardItem = "milk_bottle",
    },
    [2] = {
        coords     = vector4(1409.9387, 299.1778, 88.6308, 211.2616),
        model      = `a_c_cow`,
        radius     = 120.0,
        milkTime   = 12000,
        rewardItem = "milk_bottle",
    },
    [3] = {
        coords     = vector4(1396.1354, 286.0822, 88.6466, 128.6340),
        model      = `a_c_cow`,
        radius     = 120.0,
        milkTime   = 12000,
        rewardItem = "milk_bottle",
    },
    [4] = {
        coords     = vector4(1410.8301, 287.5908, 88.9143, 45.2901),
        model      = `a_c_cow`,
        radius     = 120.0,
        milkTime   = 12000,
        rewardItem = "milk_bottle",
    },
}

Config.Language = {
    PromptLabel    = "İnek",
    MilkPrompt     = "Süt Sağ",
    AlreadyMilking = "Bu inek şu anda sağılıyor!",
    NoTool         = "Elinde boş süt şişesi yok!",
    Milking        = "İnek sağılıyor...",
}

Config.Progressbar = {
    useVorp = true,
}

Config.RequiredItem = "empty_milk_bottle"

Config.Language = Config.Language or {}
Config.Language.NoTool = "Gerekli eşya yok!"