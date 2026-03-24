-- TurtlePvP: recap.lua — Death Recap system
-- Tracks incoming damage + CC and displays a grouped popup on death.

---------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------

local C = {
    WINDOW               = 10,  -- seconds to keep in rolling buffer
    CONTENT_W            = 480,
    LINE_H               = 14,  -- header / text / CC row
    ATTK_H               = 26,  -- attacker name row
    ATKBAR_H             = 10,  -- stacked damage bar row
    HIT_H                = 15,  -- per-spell row
    SEP_H                = 3,   -- gap between attacker blocks (no visible line, just spacing)
    ICON_SIZE            = 24,  -- class portrait
    NAME_X               = 32,
    ATKBAR_X             = 32,  -- bar aligns under name left edge
    ATKBAR_W             = 280, -- 32 + 280 + 4 + 58 + 4 = 378
    ATKBAR_H2            = 8,   -- bar fill height
    DMG_W                = 58,  -- total damage column width
    CHROME_TOP           = 28,  -- title bar height
    CHROME_BOT           = 12,  -- bottom padding inside frame (tabs sit below the frame)
    MAX_ATTACKERS        = 5,   -- grow freely up to this many; scroll beyond
    ATTKBAR_H            = 34,  -- single merged row height
    ATTKBAR_TOP_H        = 20,  -- top sub-row height (class icon + damage bar + total)
    ATTKBAR_ICON         = 20,  -- class icon size
    ATTKBAR_BX           = 100, -- bar starts here
    ATTKBAR_BW           = 322, -- bar fill width  (100 + 322 + 6 + 52 = 480)
    ATTKBAR_BH           = 10,  -- bar fill height
    STRIP_SLOTS          = 10,  -- max spell icons shown side-by-side
    STRIP_H              = 32,  -- row height (icon + dmg label below)
    STRIP_ICON           = 20,  -- icon size in pixels
    STRIP_STEP           = 26,  -- pixels per slot (icon 20 + room for 4-digit number)
    STRIP_X              = 100, -- left offset, aligns under bar
}

local CAP = 5  -- max spell slots shown per attacker; overflow → "Other" grey bucket

-- Bitmask schools (used for chat enrichment)
local SCHOOL_NAMES = {
    [1]  = "Physical",
    [2]  = "Holy",
    [4]  = "Fire",
    [8]  = "Nature",
    [16] = "Frost",
    [32] = "Shadow",
    [64] = "Arcane",
}
-- 0-indexed schools used by UNIT_COMBAT arg5
local SCHOOL_IDX = {
    [0] = "Physical",
    [1] = "Holy",
    [2] = "Fire",
    [3] = "Nature",
    [4] = "Frost",
    [5] = "Shadow",
    [6] = "Arcane",
}

-- Per-school bar fill colors (Option B: warm = physical family, cool = magic family)
-- Per-school bar fill colors: uniform hue spacing, lightened ~20% toward white for bar use.
local SCHOOL_COLORS = {
    ["Physical"] = {0.96, 0.62, 0.26},  -- orange      28°
    ["Holy"]     = {0.96, 0.90, 0.26},  -- yellow      52°
    ["Fire"]     = {0.96, 0.30, 0.26},  -- red          5°
    ["Nature"]   = {0.30, 0.88, 0.34},  -- green      120°
    ["Frost"]    = {0.26, 0.70, 0.96},  -- sky blue   200°
    ["Shadow"]   = {0.48, 0.30, 0.96},  -- periwinkle 255°
    ["Arcane"]   = {0.96, 0.32, 0.86},  -- magenta    310°
}

-- Text label versions: same hues, lightened ~15% toward white for readability on dark bg.
local SCHOOL_TEXT_COLORS = {
    ["Physical"] = {1.0,  0.88, 0.72},  -- pastel orange
    ["Holy"]     = {1.0,  1.0,  0.70},  -- pale yellow
    ["Fire"]     = {1.0,  0.75, 0.70},  -- light coral
    ["Nature"]   = {0.68, 1.0,  0.70},  -- light green
    ["Frost"]    = {0.68, 0.90, 1.0 },  -- light sky blue
    ["Shadow"]   = {0.82, 0.74, 1.0 },  -- light lavender
    ["Arcane"]   = {1.0,  0.74, 1.0 },  -- light pink
}

-- Parse WoW AARRGGBB hex string (e.g. "ffc79c6e") into r, g, b floats
local function HexToRGB(hex)
    local r = tonumber(string.sub(hex, 3, 4), 16) / 255
    local g = tonumber(string.sub(hex, 5, 6), 16) / 255
    local b = tonumber(string.sub(hex, 7, 8), 16) / 255
    return r, g, b
end

-- Known CC debuff textures -> display name (lowercase keys)
local CC_TEXTURES = {
    -- Rogue
    ["interface\\icons\\ability_cheapshot"]            = "Cheap Shot",
    ["interface\\icons\\ability_rogue_kidneyshot"]     = "Kidney Shot",
    ["interface\\icons\\ability_gouge"]                = "Gouge",
    ["interface\\icons\\ability_sap"]                  = "Sap",
    -- Mage
    ["interface\\icons\\spell_magic_polymorph"]        = "Polymorph",
    ["interface\\icons\\spell_frost_frostnova"]        = "Frost Nova",
    -- Warlock
    ["interface\\icons\\spell_shadow_possession"]      = "Fear",
    ["interface\\icons\\spell_shadow_deathscream"]     = "Howl of Terror",
    ["interface\\icons\\spell_shadow_mindsteal"]       = "Seduction",
    -- Warrior
    ["interface\\icons\\ability_warrior_charge"]       = "Charge Stun",
    ["interface\\icons\\ability_warrior_intercept"]    = "Intercept Stun",
    -- Hunter
    ["interface\\icons\\spell_frost_chainsofice"]      = "Freezing Trap",
    ["interface\\icons\\ability_hunter_scattershot"]   = "Scatter Shot",
    -- Paladin
    ["interface\\icons\\spell_holy_sealofmight"]       = "Hammer of Justice",
    -- Druid
    ["interface\\icons\\ability_druid_bash"]           = "Bash",
    ["interface\\icons\\spell_nature_polymorph"]       = "Hibernate",
    ["interface\\icons\\spell_nature_stranglevines"]   = "Entangling Roots",
    -- Priest
    ["interface\\icons\\spell_shadow_gathershadows"]   = "Blackout",
    ["interface\\icons\\spell_shadow_psychicscream"]   = "Psychic Scream",
    -- Shaman
    ["interface\\icons\\spell_shaman_hex"]             = "Hex",
}
TBGH.CC_TEXTURES = CC_TEXTURES

-- Maps CC display name -> category for the footer duration summary.
-- "stun"  = hard stun (can't act or move)
-- "inc"   = incapacitate (breaks on damage / sleep)
-- "root"  = movement-only CC
local CC_TYPE = {
    ["Cheap Shot"]        = "stun",
    ["Kidney Shot"]       = "stun",
    ["Gouge"]             = "stun",  -- technically incap but acts like a stun in practice
    ["Charge Stun"]       = "stun",
    ["Intercept Stun"]    = "stun",
    ["Hammer of Justice"] = "stun",
    ["Bash"]              = "stun",
    ["Blackout"]          = "stun",
    ["Hex"]               = "inc",
    ["Sap"]               = "inc",
    ["Polymorph"]         = "inc",
    ["Hibernate"]         = "inc",
    ["Freezing Trap"]     = "inc",
    ["Scatter Shot"]      = "inc",
    ["Fear"]              = "inc",
    ["Howl of Terror"]    = "inc",
    ["Psychic Scream"]    = "inc",
    ["Seduction"]         = "inc",
    ["Frost Nova"]        = "root",
    ["Entangling Roots"]  = "root",
}

-- Auto-invert CC_TEXTURES so CC spell names can resolve to their icon path.
local CC_ICONS = {}
for iconPath, spellName in pairs(CC_TEXTURES) do
    CC_ICONS[spellName] = iconPath
end

-- Extra-attack spell names: value is the parent spell they merge into.
-- Bar coloring and tooltip breakdown use the source name.
local EXTRA_ATTACK_SOURCES = {
    ["Windfury Attack"]      = "Auto Attack",  -- Shaman WF totem
    ["Sword Specialization"] = "Auto Attack",  -- Warrior/Rogue sword passive
    ["Hand of Justice"]      = "Auto Attack",  -- trinket proc
    ["Thrash"]               = "Auto Attack",  -- Druid bear extra attack
    ["Flurry"]               = "Auto Attack",  -- if ever logged as a named extra hit
    ["Extra Shot"]           = "Auto Shot",    -- Hunter TurtleWoW proc
}

-- Minimal hardcoded overrides: only entries that have no DBC spell record.
-- Everything else resolves via SpellInfo() → TBGH_SpellIconDB → missingIcons.
-- TurtleWoW custom spells (not in vanilla DBC, custom icon filenames) are listed here.
local SPELL_ICONS = {
    -- Combat event labels, not real spells — no DBC entry exists
    ["Auto Attack"]           = "Interface\\Icons\\ability_meleedamage",
    ["Auto Shot"]             = "Interface\\Icons\\inv_ammo_arrow_02",
    ["Windfury Attack"]       = "Interface\\Icons\\spell_nature_windfury",
    ["Extra Shot"]            = "Interface\\Icons\\ability_searingarrow",
    -- Warrior — TurtleWoW custom
    ["Master Strike"]         = "Interface\\Icons\\master_strike_1",
    ["Savage Blow"]           = "Interface\\Icons\\ability_warrior_savageblow",
    ["Decisive Strike"]       = "Interface\\Icons\\ability_warrior_decisivestrike",
    ["Victory Rush"]          = "Interface\\Icons\\ability_warrior_victoryrush",
    ["Reprisal"]              = "Interface\\Icons\\ability_warrior_reprisal",
    -- Rogue — TurtleWoW custom
    ["Smoke Bomb"]            = "Interface\\Icons\\spell_smoke_bomb_5",
    ["Shadowstep"]            = "Interface\\Icons\\ability_rogue_shadowstep",
    -- Hunter — TurtleWoW custom
    ["Noxious Assault"]       = "Interface\\Icons\\spell_double_dose_3",
    ["Explosive Ammunition"]  = "Interface\\Icons\\ability_searingarrow",
    ["Coordinated Assault"]   = "Interface\\Icons\\spell_coordinated_assault_1",
    ["Lacerate"]              = "Interface\\Icons\\spell_lacerate_1c",
    ["Disarming Shot"]        = "Interface\\Icons\\ability_hunter_disarmingshot",
    -- Shaman — TurtleWoW custom
    ["Tidal Waves"]           = "Interface\\Icons\\spell_shaman_tidalwaves",
    ["Spirit Link"]           = "Interface\\Icons\\spell_shaman_spiritlink",
    -- Mage — TurtleWoW custom
    ["Focusing Crystal"]      = "Interface\\Icons\\spell_mage_focusingcrystal",
}

-- School overrides for weapon procs and other spells that UNIT_COMBAT mis-reports as Physical.
local SPELL_SCHOOL = {
    -- Shaman weapon enchants
    ["Frostbrand Attack"]  = "Frost",
    ["Flametongue Attack"] = "Fire",
    ["Lightning Shield"]   = "Nature",
    ["Rockbiter"]          = "Nature",
    -- Shaman spells (should already be correct from UNIT_COMBAT, listed for safety)
    ["Lightning Strike"]   = "Nature",
    ["Chain Lightning"]    = "Nature",
    ["Lightning Bolt"]     = "Nature",
    ["Frost Shock"]        = "Frost",
    ["Flame Shock"]        = "Fire",
    ["Earth Shock"]        = "Nature",
    -- Warlock
    ["Shadowburn"]         = "Shadow",
    -- Hunter
    ["Immolation Trap Effect"] = "Fire",
}

-- Collects spell names that resolved to no icon, for later reporting.
-- Initially a plain table; VARIABLES_LOADED wires it to TurtlePvPDB.missingIcons.
if not TBGH.db then TBGH.db = {} end
if not TBGH.db.missingIcons then TBGH.db.missingIcons = {} end

local function GetSpellIcon(name)
    if not name then return nil end
    if SPELL_ICONS[name] then return SPELL_ICONS[name] end
    if CC_ICONS[name]    then return CC_ICONS[name]    end
    -- Strip trailing rank suffix (e.g. " VI", " (Rank 5)", " 2") and retry
    local base = string.gsub(name, "%s+%(?[IVX]+%)?$", "")  -- Roman numerals
    base = string.gsub(base, "%s+%(?[Rr]ank%s*%d+%)?$", "") -- "Rank N"
    base = string.gsub(base, "%s+%d+$", "")                  -- plain digits
    if base ~= name then
        local found = SPELL_ICONS[base] or CC_ICONS[base]
        if found then return found end
    end
    -- SuperWoW: reads live client data including encrypted patches — most accurate
    if SpellInfo then
        local _, _, icon = SpellInfo(name)
        if icon then return icon end
        if base ~= name then
            local _, _, icon2 = SpellInfo(base)
            if icon2 then return icon2 end
        end
    end
    -- Offline DBC fallback (spell_icons_generated.lua) — used when SuperWoW not active
    if TBGH_SpellIconDB then
        local icon = TBGH_SpellIconDB[name] or (base ~= name and TBGH_SpellIconDB[base])
        if icon and icon ~= "" then return "Interface\\Icons\\" .. icon end
    end
    -- Nothing worked — record for /tpvp missingicons report
    if TBGH.db then TBGH.db.missingIcons[name] = true end
end

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
TBGH.recapBuffer         = {}   -- rolling array: {time, amount, overkill, school, hitType, attacker, spell, isCC}
TBGH.lastRecap           = nil  -- snapshot set on PLAYER_DEAD
TBGH.recapChatCache      = {}   -- chat messages cached forward for UNIT_COMBAT to consume
TBGH.recapPendingEntries = {}   -- buffer entries waiting for a late chat message to fill attacker/spell
TBGH.recapPrevDebuffs    = {}   -- previous debuff texture set for CC diff
TBGH.recapActiveCCs      = {}   -- key -> buffer entry, for stamping ccEnd when debuff drops
TBGH.recapLog            = {}   -- ring buffer of last 200 debug messages (always filled)

-- Forward declaration so RecapOnDead (defined below) can call it
-- Assigned when the prompt frame is created further down this file
local ShowRecapPrompt

---------------------------------------------------------------------
-- Internal log helper — always stores to recapLog, shows in chat
-- only when recapDebug is on.
---------------------------------------------------------------------
function TBGH:RecapAddLog(msg)
    local log = self.recapLog
    table.insert(log, msg)
    if table.getn(log) > 200 then table.remove(log, 1) end
    if self.db and self.db.recapDebug then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

---------------------------------------------------------------------
-- Reset (called on PLAYER_ENTERING_WORLD)
---------------------------------------------------------------------
function TBGH:RecapReset()
    self:RecapAddLog("[RecapDebug] RecapReset called (was " .. table.getn(self.recapBuffer) .. " entries)")
    self.recapBuffer         = {}
    self.recapChatCache      = {}
    self.recapPendingEntries = {}
    self.recapPrevDebuffs    = {}
    self.recapActiveCCs      = {}
end

---------------------------------------------------------------------
-- Evict entries older than C.WINDOW from front of buffer
---------------------------------------------------------------------
function TBGH:RecapEvict()
    local cutoff = GetTime() - C.WINDOW
    local buf = self.recapBuffer
    while buf[1] ~= nil and buf[1].time < cutoff do
        table.remove(buf, 1)
    end
end

---------------------------------------------------------------------
-- UNIT_COMBAT handler — called when arg1 == "player"
---------------------------------------------------------------------
function TBGH:RecapOnUnitCombat(action, modifier, amount, school)
    if not self.db or not self.db.recapEnabled then return end
    -- Opportunistically populate classCache from all visible unit IDs
    self:ScanClassesNow()
    -- action   = arg2: WOUND / HEAL / BLOCK / ABSORB / DEFLECT etc.
    -- modifier = arg3: CRITICAL / CRUSHING / GLANCING / ""
    -- amount   = arg4
    -- school   = arg5: 0=Physical 1=Holy 2=Fire 3=Nature 4=Frost 5=Shadow 6=Arcane
    if action ~= "WOUND" then return end  -- only care about incoming damage
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local hitType
    if     modifier == "CRITICAL"  then hitType = "crit"
    elseif modifier == "CRUSHING"  then hitType = "crushing"
    elseif modifier == "GLANCING"  then hitType = "glancing"
    else hitType = "hit" end

    local schoolNum = tonumber(school)

    local entry = {
        time     = GetTime(),
        amount   = amount,
        overkill = 0,
        school   = SCHOOL_IDX[schoolNum] or "Physical",
        hitType  = hitType,
        attacker = nil,
        class    = nil,
        spell    = nil,
        enriched = false,
        isCC     = false,
    }
    -- Look up the chat cache for attacker/spell info (chat arrives BEFORE UNIT_COMBAT)
    -- When this is a crit, prefer a cache entry that also says crit to avoid wrong-hit theft.
    local cache = self.recapChatCache
    local now = GetTime()
    local isCrit = (hitType == "crit")
    local bestCI = nil
    -- First pass: try to find an entry with matching hitType (crit vs non-crit)
    for ci = table.getn(cache), 1, -1 do
        local ce = cache[ci]
        if ce.amount == amount and (now - ce.time) < 8.0 then
            if isCrit == (ce.hitType == "crit") then
                bestCI = ci
                break
            end
        end
    end
    -- Second pass: fall back to any amount match if no same-type found
    if not bestCI then
        for ci = table.getn(cache), 1, -1 do
            local ce = cache[ci]
            if ce.amount == amount and (now - ce.time) < 8.0 then
                bestCI = ci
                break
            end
        end
    end
    if bestCI then
        local ce = cache[bestCI]
        entry.attacker = ce.attacker
        entry.class    = ce.class
        entry.spell    = ce.spell
        if ce.hitType then entry.hitType = ce.hitType end
        if ce.spell and SPELL_SCHOOL[ce.spell] then entry.school = SPELL_SCHOOL[ce.spell] end
        entry.enriched = true
        table.remove(cache, bestCI)
        self:RecapAddLog("[RecapDebug] ChatCache hit: " .. tostring(ce.attacker) .. " / " .. tostring(ce.spell) .. " / " .. tostring(amount))
    else
        -- Chat may arrive AFTER UNIT_COMBAT for some events (e.g. Deep Wound).
        -- Park the entry so RecapEnrichFromChat can fill it in retroactively.
        local pending = self.recapPendingEntries
        table.insert(pending, entry)
        if table.getn(pending) > 20 then table.remove(pending, 1) end
    end
    self:RecapEvict()
    local buf = self.recapBuffer
    table.insert(buf, entry)
    self:RecapAddLog("[RecapDebug] Buffered " .. amount .. " dmg; buf size=" .. table.getn(buf))
end

---------------------------------------------------------------------
-- Chat enrichment — attaches attacker/spell/hitType to latest entry
-- msgType: "melee" (CHAT_MSG_COMBAT_SELF_HITS)
--          "spell" (CHAT_MSG_SPELL_SELF_DAMAGE)
---------------------------------------------------------------------
function TBGH:RecapEnrichFromChat(msg, msgType)
    -- Only log the raw message when it looks relevant to the player, or when debug is on
    local looksRelevant = string.find(msg, "you for") or string.find(msg, "You suffer") or string.find(msg, "you for 0")
    if looksRelevant or (self.db and self.db.recapDebug) then
        self:RecapAddLog("[RecapRaw] " .. msgType .. ": " .. string.sub(msg, 1, 80))
    end
    if not self.db or not self.db.recapEnabled then return end

    local attacker, spell, hitType, chatAmt

    if msgType == "melee" then
        local _, _, src, amt = string.find(msg, "^(.+) hits you for (%d+)")
        if src then attacker = src; hitType = "hit"; chatAmt = tonumber(amt) end
        if not attacker then
            _, _, src, amt = string.find(msg, "^(.+) crits you for (%d+)")
            if src then attacker = src; hitType = "crit"; chatAmt = tonumber(amt) end
        end

    elseif msgType == "spell" then
        local _, _, src, sp, amt = string.find(msg, "^(.-)%'s (.+) hits you for (%d+) %a+ damage")
        if src then attacker = src; spell = sp; hitType = "hit"; chatAmt = tonumber(amt) end
        if not attacker then
            _, _, src, sp, amt = string.find(msg, "^(.-)%'s (.+) crits you for (%d+) %a+ damage")
            if src then attacker = src; spell = sp; hitType = "crit"; chatAmt = tonumber(amt) end
        end
        if not attacker then
            _, _, src, sp, amt = string.find(msg, "^(.-)%'s (.+) hits you for (%d+)%.")
            if src then attacker = src; spell = sp; hitType = "hit"; chatAmt = tonumber(amt) end
        end
        if not attacker then
            _, _, src, sp, amt = string.find(msg, "^(.-)%'s (.+) crits you for (%d+)%.")
            if src then attacker = src; spell = sp; hitType = "crit"; chatAmt = tonumber(amt) end
        end
        -- DoT / periodic: "Src's SpellName bleeds/burns/etc you for N."
        -- "You suffer N damage from Src's SpellName."
        if not attacker then
            _, _, src, sp, amt = string.find(msg, "^(.-)%'s (.+) bleeds you for (%d+)")
            if src then attacker = src; spell = sp; hitType = "dot"; chatAmt = tonumber(amt) end
        end
        if not attacker then
            _, _, src, sp, amt = string.find(msg, "^(.-)%'s (.+) burns you for (%d+)")
            if src then attacker = src; spell = sp; hitType = "dot"; chatAmt = tonumber(amt) end
        end
        if not attacker then
            _, _, src, sp, amt = string.find(msg, "^(.-)%'s (.+) poisons you for (%d+)")
            if src then attacker = src; spell = sp; hitType = "dot"; chatAmt = tonumber(amt) end
        end
        if not attacker then
            _, _, src, sp, amt = string.find(msg, "^(.-)%'s (.+) afflicts you for (%d+)")
            if src then attacker = src; spell = sp; hitType = "dot"; chatAmt = tonumber(amt) end
        end
        if not attacker then
            -- "You suffer 78 damage from Hatdood's Rupture."
            -- "You suffer 73 Shadow damage from Persvako's Qiraji Deterioration."
            -- (.-) between amount and "damage" absorbs optional school word
            _, _, amt, src, sp = string.find(msg, "^You suffer (%d+) .-damage from (.-)%'s (.+)%.")
            if src then attacker = src; spell = sp; hitType = "dot"; chatAmt = tonumber(amt) end
        end
    end

    if not attacker or not chatAmt or chatAmt <= 0 then return end

    -- Attribute totem/guardian damage to their owner.
    -- Names like "Searing Totem VI (Xupale)" contain the owner in parentheses.
    local _, _, totemOwner = string.find(attacker, "%((.-)%)$")
    if totemOwner then attacker = totemOwner end

    -- Prime class cache: attacker just hit us, they are likely our current target now
    local attackerClass = TBGH:GetClassByName(attacker)

    -- Backward-fill: if UNIT_COMBAT already fired before this chat message arrived,
    -- find the latest unenriched pending entry with the same amount and fill it in.
    local now2 = GetTime()
    local pending = self.recapPendingEntries
    for pi = table.getn(pending), 1, -1 do
        local pe = pending[pi]
        if pe.amount == chatAmt and not pe.enriched and (now2 - pe.time) < 8.0 then
            pe.attacker = attacker
            pe.class    = attackerClass
            pe.spell    = spell
            if hitType then pe.hitType = hitType end
            if spell and SPELL_SCHOOL[spell] then pe.school = SPELL_SCHOOL[spell] end
            pe.enriched = true
            table.remove(pending, pi)
            self:RecapAddLog("[RecapDebug] PendingFill: " .. tostring(attacker) .. " / " .. tostring(spell) .. " / " .. tostring(chatAmt))
            return  -- consumed; don't forward-cache it too
        end
    end

    -- Store in cache so UNIT_COMBAT (which fires after) can consume it
    self:RecapAddLog("[RecapDebug] ChatCache store: " .. tostring(attacker) .. " / " .. tostring(spell) .. " / " .. tostring(chatAmt))
    local cache = self.recapChatCache
    table.insert(cache, {
        amount   = chatAmt,
        attacker = attacker,
        class    = attackerClass,
        spell    = spell,
        hitType  = hitType,
        time     = GetTime(),
    })
    if table.getn(cache) > 30 then table.remove(cache, 1) end
end

---------------------------------------------------------------------
-- CC detection via UNIT_AURA — diff current debuffs against previous
---------------------------------------------------------------------
function TBGH:RecapCheckCC()
    if not self.db or not self.db.recapEnabled then return end
    local prev = self.recapPrevDebuffs
    local active = self.recapActiveCCs
    local curr = {}
    local i = 1
    while true do
        local tex, stacks, debuffType, duration = UnitDebuff("player", i)
        if not tex then break end
        local key = string.lower(tex)
        curr[key] = true
        if not prev[key] then
            local ccName = CC_TEXTURES[key]
            if ccName then
                self:RecapEvict()
                local now = GetTime()
                -- If the API gives us a duration (SuperWoW extension), pre-fill ccEnd
                local preEnd = (duration and duration > 0) and (now + duration) or nil
                local entry = {
                    time    = now,
                    isCC    = true,
                    ccName  = ccName,
                    ccEnd   = preEnd,
                }
                table.insert(self.recapBuffer, entry)
                -- Only track in activeCCs if duration isn't already known
                if not preEnd then
                    active[key] = entry
                end
            end
        end
        i = i + 1
    end
    -- Stamp ccEnd on any CC that just dropped
    -- Collect keys first; Lua 5.0 can't nil-out keys while iterating pairs
    local dropped = {}
    for key, entry in pairs(active) do
        if not curr[key] then
            entry.ccEnd = GetTime()
            table.insert(dropped, key)
        end
    end
    for _, key in ipairs(dropped) do
        active[key] = nil
    end
    self.recapPrevDebuffs = curr
end

---------------------------------------------------------------------
-- Snapshot buffer on PLAYER_DEAD and show popup
---------------------------------------------------------------------
function TBGH:RecapOnDead()
    if not self.db or not self.db.recapEnabled then return end
    if not TBGH_GetBGType() then return end
    -- Stamp ccEnd on any CC still active at death (player died while stunned)
    local deathTime = GetTime()
    local activeKeys = {}
    for key in pairs(self.recapActiveCCs) do table.insert(activeKeys, key) end
    for _, key in ipairs(activeKeys) do
        local entry = self.recapActiveCCs[key]
        if not entry.ccEnd then
            entry.ccEnd = deathTime
        end
        self.recapActiveCCs[key] = nil
    end
    self:RecapAddLog("[RecapDebug] RecapOnDead: buf size before evict=" .. table.getn(self.recapBuffer))
    self:RecapEvict()
    self:RecapAddLog("[RecapDebug] RecapOnDead: buf size after evict=" .. table.getn(self.recapBuffer))
    local buf = self.recapBuffer
    if table.getn(buf) == 0 then
        -- No damage events were captured — still record so /tpvp recap gives feedback
        self.lastRecap = {
            snapshot       = {},
            attackerOrder  = {},
            attackerGroups = {},
            totalDamage    = 0,
            overkill       = 0,
            killingEntry   = nil,
            maxHP          = UnitHealthMax("player") or 0,
            noDamageData   = true,
        }
        self:ShowRecapFrame()
        return
    end

    -- Find killing blow: last damage entry with overkill > 0, else last damage entry
    local killingEntry = nil
    for idx = table.getn(buf), 1, -1 do
        local e = buf[idx]
        if not e.isCC and (e.overkill or 0) > 0 then
            killingEntry = e
            break
        end
    end
    if not killingEntry then
        for idx = table.getn(buf), 1, -1 do
            if not buf[idx].isCC then killingEntry = buf[idx]; break end
        end
    end

    -- Group damage by attacker (first-seen order), track class per attacker
    local attackerOrder  = {}
    local attackerGroups = {}
    local attackerClass  = {}  -- key -> class string (from first enriched hit)
    local totalDamage    = 0
    local totalOverkill  = 0

    for idx = 1, table.getn(buf) do
        local e = buf[idx]
        if not e.isCC then
            -- Skip hits that were never attributed to an attacker
            if not e.attacker then
                self:RecapAddLog("[RecapDebug] Dropping unattributed hit: " .. tostring(e.amount) .. " dmg")
            else
                local key = e.attacker
                if not attackerGroups[key] then
                    attackerGroups[key] = { total = 0, hits = {} }
                    table.insert(attackerOrder, key)
                end
                local grp = attackerGroups[key]
                grp.total = grp.total + e.amount
                table.insert(grp.hits, e)
                totalDamage  = totalDamage  + e.amount
                totalOverkill = totalOverkill + (e.overkill or 0)
                if e.class and not attackerClass[key] then
                    attackerClass[key] = e.class
                end
            end
        end
    end

    -- Snapshot buffer so RecapReset() doesn't destroy it
    local snapshot = {}
    for idx = 1, table.getn(buf) do snapshot[idx] = buf[idx] end

    self.lastRecap = {
        snapshot       = snapshot,
        attackerOrder  = attackerOrder,
        attackerGroups = attackerGroups,
        attackerClass  = attackerClass,
        totalDamage    = totalDamage,
        overkill       = totalOverkill,
        killingEntry   = killingEntry,
        maxHP          = UnitHealthMax("player") or 0,
    }

    if self.db.recapAutoExpand then
        self:ShowRecapFrame()
    else
        ShowRecapPrompt()
    end
end

-- Attacker row: portrait at x=4, name at x=32, bar starts under name

-- Frame chrome (pixels outside the scrollable content area)

-- Compact combined attacker+bar row (replaces separate "attacker" + "atkbar" rows)

-- Spell strip: horizontal icon row under the stacked bar (LoL style)

-- LoL palette (kept for reference, not used for bar fills now)

---------------------------------------------------------------------
-- Build display lines from recap snapshot
---------------------------------------------------------------------
local function BuildRecapLines(recap)
    local lines = {}

    local function AddHeader(text, r, g, b)
        table.insert(lines, { lineType="header", text=text, r=r or 1, g=g or 1, b=b or 1 })
    end
    local function AddSep()
        table.insert(lines, { lineType="sep" })
    end
    local function AddAttacker(name, totalDmg, r, g, b, iconTex, iconCoords, isKill)
        table.insert(lines, { lineType="attacker", text=name,
            totalDmg=totalDmg, r=r or 1, g=g or 1, b=b or 1,
            iconTex=iconTex, iconCoords=iconCoords, isKill=isKill })
    end
    local function AddAtkBar(spells, totalDmg, barFrac)
        table.insert(lines, { lineType="atkbar",
            spells=spells, totalDmg=totalDmg, barFrac=barFrac })
    end
    local function AddAttackerBar(name, totalDmg, r, g, b, iconTex, iconCoords, isKill, spells, barFrac)
        local bgStats = TBGH.bgScoreCache and TBGH.bgScoreCache[name]
        table.insert(lines, { lineType="attackerbar", text=name,
            totalDmg=totalDmg, r=r or 1, g=g or 1, b=b or 1,
            iconTex=iconTex, iconCoords=iconCoords, isKill=isKill,
            spells=spells, barFrac=barFrac, bgStats=bgStats })
    end
    local function AddSpellStrip(spells)
        table.insert(lines, { lineType="spellstrip", spells=spells })
    end
    local function AddText(text, r, g, b)
        table.insert(lines, { lineType="text", text=text, r=r or 1, g=g or 1, b=b or 1 })
    end
    local function AddCCSummary(summaryText, tooltipLines)
        table.insert(lines, { lineType="ccsummary", text=summaryText,
            r=0.9, g=0.7, b=0.2, tooltipLines=tooltipLines })
    end

    if recap.noDamageData then
        AddHeader("Death Recap: no damage events captured.", 1, 0.82, 0)
        AddText("", 0.5, 0.5, 0.5)
        AddText("This can happen if:", 0.75, 0.75, 0.75)
        AddText("  - Death Recap was just enabled this session", 0.75, 0.75, 0.75)
        AddText("  - You died from a DoT with no direct hits", 0.75, 0.75, 0.75)
        AddText("  - UNIT_COMBAT events did not fire", 0.75, 0.75, 0.75)
        return lines
    end

    local nAtk  = table.getn(recap.attackerOrder)
    local maxHP = math.max(recap.maxHP or 1, 1)
    -- Overall physical vs magical split for header display
    local hdrPhys, hdrMag = 0, 0
    for oi = 1, table.getn(recap.attackerOrder) do
        local grp = recap.attackerGroups[recap.attackerOrder[oi]]
        for j = 1, table.getn(grp.hits) do
            local e = grp.hits[j]
            if e.school == "Physical" then hdrPhys = hdrPhys + e.amount
            else                           hdrMag  = hdrMag  + e.amount end
        end
    end
    -- Sort attackers by total damage desc
    local sorted = {}
    for i = 1, table.getn(recap.attackerOrder) do table.insert(sorted, recap.attackerOrder[i]) end
    table.sort(sorted, function(a, b)
        return (recap.attackerGroups[a].total or 0) > (recap.attackerGroups[b].total or 0)
    end)

    -- Bars are proportional to the highest individual attacker (top attacker = full bar)
    local maxAtkTotal = 1
    for i = 1, table.getn(sorted) do
        local tot = recap.attackerGroups[sorted[i]].total or 0
        if tot > maxAtkTotal then maxAtkTotal = tot end
    end

    for i = 1, table.getn(sorted) do
        local key = sorted[i]
        local grp = recap.attackerGroups[key]
        AddSep()

        local cls = (recap.attackerClass and recap.attackerClass[key])
            or TBGH:GetClassByName(key)
            or TBGH:InferClassFromSpells(grp.hits)
        if cls and not TBGH.classCache[key] then TBGH.classCache[key] = cls end
        local cr, cg, cb = 1, 1, 1
        local iconTex, iconCoords
        if cls and TBGH.CLASS_COLORS[cls] then cr, cg, cb = HexToRGB(TBGH.CLASS_COLORS[cls]) end
        if cls and TBGH.CLASS_TCOORDS[cls] then
            iconTex = TBGH.CLASS_ICONS
            iconCoords = TBGH.CLASS_TCOORDS[cls]
        end

        -- Merge hits by spell; tally physical vs magical
        local spellOrder  = {}
        local spellGroups = {}
        local physTotal, magTotal = 0, 0
        local atkIsKill = false
        for j = 1, table.getn(grp.hits) do
            local e         = grp.hits[j]
            local rawSpell  = e.spell or "Auto Attack"
            -- Extra-attack procs: merge damage into parent spell group, track source separately
            local mergeTarget = EXTRA_ATTACK_SOURCES[rawSpell]
            local isExtra     = (mergeTarget ~= nil)
            local sName       = isExtra and mergeTarget or rawSpell
            local htype     = e.hitType or "hit"
            local isCrit    = (htype == "crit" or htype == "crushing")
            local isKillHit = (e == recap.killingEntry)
            if not spellGroups[sName] then
                spellGroups[sName] = { total=0, count=0, school=e.school,
                                       hasCrit=false, isKill=false, hits={},
                                       extraSources={}, extraTotal=0 }
                table.insert(spellOrder, sName)
            end
            local sg = spellGroups[sName]
            sg.total  = sg.total  + e.amount
            sg.count  = sg.count  + 1
            if isCrit    then sg.hasCrit = true end
            if isKillHit then sg.isKill = true; atkIsKill = true end
            if isExtra then
                if not sg.extraSources[rawSpell] then
                    sg.extraSources[rawSpell] = { hits={}, total=0 }
                end
                local es = sg.extraSources[rawSpell]
                table.insert(es.hits, { amount=e.amount, isCrit=isCrit })
                es.total     = es.total     + e.amount
                sg.extraTotal = sg.extraTotal + e.amount
            else
                table.insert(sg.hits, { amount=e.amount, isCrit=isCrit })
            end
            if e.school == "Physical" then physTotal = physTotal + e.amount
            else                           magTotal  = magTotal  + e.amount end
        end

        -- Sort spells by damage desc
        table.sort(spellOrder, function(a, b)
            return spellGroups[a].total > spellGroups[b].total
        end)

        local tot     = grp.total
        local barFrac = tot / maxAtkTotal

        local spellList = {}
        for si = 1, table.getn(spellOrder) do
            local sName = spellOrder[si]
            local sg    = spellGroups[sName]
            table.insert(spellList, {
                icon         = GetSpellIcon(sName),
                name         = sName,
                dmgText      = tostring(sg.total),
                dmgAmt       = sg.total,
                school       = sg.school,
                isCrit       = sg.hasCrit,
                isKill       = sg.isKill,
                hitCount     = sg.count,
                hits         = sg.hits,
                extraSources = sg.extraSources or {},
                extraTotal   = sg.extraTotal   or 0,
            })
        end

        AddAttackerBar(key, tot, cr, cg, cb, iconTex, iconCoords, atkIsKill, spellList, barFrac)
    end

    -- CC section
    local ccSeen = {}
    local stunTotal = 0
    local incTotal  = 0
    local rootTotal = 0
    for idx = 1, table.getn(recap.snapshot) do
        local e = recap.snapshot[idx]
        if e.isCC then
            local dur = e.ccEnd and (e.ccEnd - e.time) or nil
            -- Sanity-clamp: max real stun ~10s, roots ~15s; discard bogus durations (e.g. from stale timestamps)
            if dur and (dur < 0 or dur > 15) then dur = nil end
            table.insert(ccSeen, { name=e.ccName, dur=dur })
            if dur then
                local cat = CC_TYPE[e.ccName]
                if     cat == "stun" then stunTotal = stunTotal + dur
                elseif cat == "inc"  then incTotal  = incTotal  + dur
                elseif cat == "root" then rootTotal = rootTotal + dur
                end
            end
        end
    end
    -- Hoist onto recap so ShowRecapFrame can access them for the header bar
    recap.stunTotal = stunTotal
    recap.incTotal  = incTotal
    recap.rootTotal = rootTotal
    recap.ccTtLines = nil
    if table.getn(ccSeen) > 0 then
        -- Tooltip detail: one line per CC instance {name, durStr}
        local ttLines = {}
        for i = 1, table.getn(ccSeen) do
            local cc = ccSeen[i]
            table.insert(ttLines, {
                name = cc.name,
                dur  = cc.dur and string.format("%.1fs", cc.dur) or "",
            })
        end
        -- Summary string: only totals that are non-zero
        local parts = {}
        if stunTotal > 0 then
            table.insert(parts, string.format("Stunned %.1fs", stunTotal))
        end
        if incTotal > 0 then
            table.insert(parts, string.format("Incap %.1fs", incTotal))
        end
        if rootTotal > 0 then
            table.insert(parts, string.format("Rooted %.1fs", rootTotal))
        end
        -- If all durations unknown, fall back to listing names
        if table.getn(parts) == 0 then
            for i = 1, table.getn(ccSeen) do
                table.insert(parts, ccSeen[i].name)
            end
        end
        local summary = ""
        for p = 1, table.getn(parts) do
            if p > 1 then summary = summary .. "   " end
            summary = summary .. parts[p]
        end
        recap.ccTtLines = ttLines
    end

    return lines
end

---------------------------------------------------------------------
-- Popup frame
---------------------------------------------------------------------
local recapFrame = CreateFrame("Frame", "TurtlePvPRecapFrame", UIParent)
recapFrame:SetWidth(516)
recapFrame:SetHeight(100)  -- will be resized dynamically in ShowRecapFrame
recapFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
recapFrame:SetFrameStrata("HIGH")
recapFrame:SetFrameLevel(10)
recapFrame:SetMovable(true)
recapFrame:EnableMouse(true)
recapFrame:SetClampedToScreen(true)
recapFrame:RegisterForDrag("LeftButton")
recapFrame:SetScript("OnDragStart", function() recapFrame:StartMoving() end)
recapFrame:SetScript("OnDragStop",  function() recapFrame:StopMovingOrSizing() end)
recapFrame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
recapFrame:SetBackdropColor(0, 0, 0, 0.88)
recapFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
recapFrame:Hide()

---------------------------------------------------------------------
-- Death recap prompt: 10s clickable toast shown on death
---------------------------------------------------------------------
local recapPrompt = CreateFrame("Button", "TurtlePvPRecapPrompt", UIParent)
recapPrompt:SetWidth(180)
recapPrompt:SetHeight(36)
recapPrompt:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
recapPrompt:SetFrameStrata("DIALOG")
recapPrompt:SetFrameLevel(60)
recapPrompt:EnableMouse(true)
recapPrompt:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
recapPrompt:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
recapPrompt:SetBackdropBorderColor(0.6, 0.15, 0.15, 1)
recapPrompt:Hide()

local recapPromptIcon = recapPrompt:CreateTexture(nil, "OVERLAY")
recapPromptIcon:SetWidth(20)
recapPromptIcon:SetHeight(20)
recapPromptIcon:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
recapPromptIcon:SetPoint("RIGHT", recapPromptText, "LEFT", -4, 0)

local recapPromptText = recapPrompt:CreateFontString(nil, "OVERLAY")
recapPromptText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
recapPromptText:SetPoint("CENTER", recapPrompt, "CENTER", 0, 0)
recapPromptText:SetTextColor(0.95, 0.85, 0.25)
recapPromptText:SetText("Death Recap  (10)")

local recapPromptTimer = nil
local recapPromptSecondsLeft = 0

local function RecapPromptTick()
    recapPromptSecondsLeft = recapPromptSecondsLeft - 1
    if recapPromptSecondsLeft <= 0 then
        recapPrompt:Hide()
        recapPromptTimer = nil
    else
        recapPromptText:SetText("Death Recap  (" .. recapPromptSecondsLeft .. ")")
        recapPromptTimer = recapPrompt:GetParent()
        -- re-schedule via a one-shot OnUpdate
        local elapsed = 0
        recapPrompt:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= 1 then
                recapPrompt:SetScript("OnUpdate", nil)
                RecapPromptTick()
            end
        end)
    end
end

ShowRecapPrompt = function()
    recapPromptSecondsLeft = 10
    recapPromptText:SetText("Death Recap  (10)")
    recapPrompt:Show()
    local elapsed = 0
    recapPrompt:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 1 then
            recapPrompt:SetScript("OnUpdate", nil)
            RecapPromptTick()
        end
    end)
end

recapPrompt:SetScript("OnClick", function()
    recapPrompt:SetScript("OnUpdate", nil)
    recapPrompt:Hide()
    TBGH:ShowRecapFrame()
end)
recapPrompt:SetScript("OnEnter", function()
    recapPrompt:SetBackdropBorderColor(1, 0.4, 0.2, 1)
end)
recapPrompt:SetScript("OnLeave", function()
    recapPrompt:SetBackdropBorderColor(0.6, 0.15, 0.15, 1)
end)

-- Faction icon — UIParent child anchored to recap so it always renders on top
local recapFactionFrame = CreateFrame("Frame", "TurtlePvPRecapFactionFrame", UIParent)
recapFactionFrame:SetWidth(24)
recapFactionFrame:SetHeight(24)
recapFactionFrame:SetFrameStrata("HIGH")
recapFactionFrame:SetFrameLevel(50)
recapFactionFrame:SetPoint("TOPLEFT", recapFrame, "TOPLEFT", -6, -8)
recapFactionFrame:Hide()
local recapFactionIcon = recapFactionFrame:CreateTexture(nil, "OVERLAY")
recapFactionIcon:SetAllPoints(recapFactionFrame)
recapFactionIcon:SetTexCoord(0.09, 0.63, 0.05, 0.63)
recapFactionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")  -- updated at show time

-- Small skull in the header, before the title text
local recapHeaderSkull = recapFrame:CreateTexture(nil, "OVERLAY")
recapHeaderSkull:SetWidth(16)
recapHeaderSkull:SetHeight(16)
recapHeaderSkull:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
recapHeaderSkull:SetPoint("LEFT", recapFrame, "TOPLEFT", 18, -20)

local recapTitle = recapFrame:CreateFontString(nil, "OVERLAY")
recapTitle:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
recapTitle:SetPoint("TOPLEFT", recapFrame, "TOPLEFT", 38, -14)
recapTitle:SetTextColor(0.87, 0.73, 0.27)
recapTitle:SetText("Death Recap")

local recapClose = CreateFrame("Button", "TurtlePvPRecapClose", recapFrame, "UIPanelCloseButton")
recapClose:SetPoint("TOPRIGHT", recapFrame, "TOPRIGHT", -4, -4)

-- "Always show" checkbox in the title bar
local recapAlwaysShowCheck = CreateFrame("CheckButton", "TurtlePvPRecapAlwaysShowCheck", recapFrame, "UICheckButtonTemplate")
recapAlwaysShowCheck:SetWidth(20)
recapAlwaysShowCheck:SetHeight(20)
recapAlwaysShowCheck:SetPoint("RIGHT", recapClose, "LEFT", -2, 0)
recapAlwaysShowCheck:SetScript("OnClick", function()
    if TBGH.db then
        TBGH.db.recapAutoExpand = this:GetChecked() and true or false
        -- Keep the settings panel in sync if it is open
        if TBGH._recapExpandCheck then
            TBGH._recapExpandCheck:SetChecked(TBGH.db.recapAutoExpand == true)
        end
    end
end)
recapAlwaysShowCheck:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Always Show", 1, 1, 1)
    GameTooltip:AddLine("Expand the Death Recap\nautomatically on every death.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
recapAlwaysShowCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

local recapAlwaysShowLabel = recapFrame:CreateFontString(nil, "OVERLAY")
recapAlwaysShowLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
recapAlwaysShowLabel:SetTextColor(0.75, 0.75, 0.75)
recapAlwaysShowLabel:SetText("Always show")
recapAlwaysShowLabel:SetPoint("RIGHT", recapAlwaysShowCheck, "LEFT", 1, 0)

-- Info tabs: two tab buttons sitting above/below recapFrame (damage + stun/CC)
-- Uses the actual UI-Character-ActiveTab texture sliced into left/mid/right caps
-- flipV=true  → open side faces down (tab sits on top of frame)
-- flipV=false → open side faces up   (tab sits on bottom of frame)
local function MakeInfoTab(frameName, flipV, r, g, b, inactive)
    local f = CreateFrame("Frame", frameName, UIParent)
    f:SetHeight(30)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(20)
    f:EnableMouse(true)
    f:Hide()

    local v0, v1 = 0, 1   -- normal: open side up
    if flipV then v0, v1 = 1, 0 end  -- flipped: open side down

    local tabTex = inactive
        and "Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab"
        or  "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab"

    local L = f:CreateTexture(nil, "BACKGROUND")
    L:SetTexture(tabTex)
    L:SetWidth(32)
    L:SetPoint("LEFT",   f, "LEFT",   0, 0)
    L:SetPoint("TOP",    f, "TOP",    0, 0)
    L:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    L:SetTexCoord(0, 0.25, v0, v1)
    L:SetVertexColor(r, g, b)

    local R = f:CreateTexture(nil, "BACKGROUND")
    R:SetTexture(tabTex)
    R:SetWidth(32)
    R:SetPoint("RIGHT",  f, "RIGHT",  0, 0)
    R:SetPoint("TOP",    f, "TOP",    0, 0)
    R:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    R:SetTexCoord(0.75, 1, v0, v1)
    R:SetVertexColor(r, g, b)

    local M = f:CreateTexture(nil, "BACKGROUND")
    M:SetTexture(tabTex)
    M:SetPoint("LEFT",   L, "RIGHT", 0, 0)
    M:SetPoint("RIGHT",  R, "LEFT",  0, 0)
    M:SetPoint("TOP",    f, "TOP",    0, 0)
    M:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    M:SetTexCoord(0.25, 0.75, v0, v1)
    M:SetVertexColor(r, g, b)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    label:SetJustifyH("CENTER")
    label:SetText("")
    f.label = label

    return f
end

local physTab = MakeInfoTab("TurtlePvPRecapPhysTab", false, 1.0, 0.88, 0.55, true)   -- bottom-left: bright warm orange, inactive
physTab.label:SetPoint("CENTER", physTab, "CENTER", 0, 2)

local magTab = MakeInfoTab("TurtlePvPRecapMagTab", false, 0.55, 0.90, 1.0, true)    -- bottom-right: bright sky blue, inactive
magTab.label:SetPoint("CENTER", magTab, "CENTER", 0, 2)

local stunTab = MakeInfoTab("TurtlePvPRecapStunTab", false, 1.0, 1.0, 1.0)   -- bottom: default

local stunTabIcon = stunTab:CreateTexture(nil, "OVERLAY")
stunTabIcon:SetWidth(14)
stunTabIcon:SetHeight(14)
stunTabIcon:SetTexture("Interface\\Icons\\spell_frost_stun")
stunTabIcon:Hide()

recapFrame:SetScript("OnHide", function() physTab:Hide(); magTab:Hide(); stunTab:Hide(); recapFactionFrame:Hide() end)

---------------------------------------------------------------------
-- Bar/slot cross-highlight wiring (module-level to avoid upvalue limit)
-- Called once per attackerbar row after fills and slots are positioned.
---------------------------------------------------------------------
local function WireBarHighlight(bFills, bFrames, slots, n, spells, wfFills)
    for hi = 1, n do
        local myIdx   = hi   -- new local per iteration; for-var is shared in Lua 5.0
        local sp      = spells[hi]
        local ttName   = sp.name
        local ttSchool = sp.school
        local ttDmg    = sp.dmgText
        local ttCount  = sp.hitCount
        local ttCrit        = sp.isCrit
        local ttExtraSrc    = sp.extraSources or {}
        local ttExtraTotal  = sp.extraTotal   or 0
        local bfr      = bFrames[hi]
        local slot     = slots[hi]

        local function doHighlight()
            for k = 1, n do
                local a = (k == myIdx) and 1.0 or 0.25
                bFills[k]:SetAlpha(a)
                if wfFills and wfFills[k] then wfFills[k]:SetAlpha(a) end
                slots[k].icon:SetAlpha(a)
            end
        end
        local function doClear()
            for k = 1, n do
                bFills[k]:SetAlpha(0.60)
                if wfFills and wfFills[k] then wfFills[k]:SetAlpha(0.60) end
                slots[k].icon:SetAlpha(1.0)
            end
        end
        local function showTT(owner, anchor)
            doHighlight()
            GameTooltip:SetOwner(owner, anchor)
            GameTooltip:ClearLines()
            -- Name
            GameTooltip:AddLine(ttName, 1, 1, 1)
            -- School line (colored)
            local sc2 = SCHOOL_TEXT_COLORS[ttSchool] or SCHOOL_TEXT_COLORS["Physical"]
            GameTooltip:AddLine(ttSchool .. " damage", sc2[1], sc2[2], sc2[3])
            -- Critical strikes note (3rd row, only if crits present)
            if ttCrit then
                GameTooltip:AddLine("Critical Strikes", 1.0, 0.85, 0.0)
            end
            -- Individual hits: name left, amount right (yellow if crit)
            local ttHits = sp.hits
            if ttHits and table.getn(ttHits) > 0 then
                GameTooltip:AddLine(" ", 1, 1, 1)  -- spacer
                for _, h in ipairs(ttHits) do
                    if h.isCrit then
                        GameTooltip:AddDoubleLine(ttName, tostring(h.amount),
                            0.85, 0.85, 0.85,
                            1.0, 0.85, 0.0)
                    else
                        GameTooltip:AddDoubleLine(ttName, tostring(h.amount),
                            0.85, 0.85, 0.85,
                            0.85, 0.85, 0.85)
                    end
                end
            end
            -- Extra-attack procs (Windfury, Sword Spec, etc.) merged into this hit group
            if ttExtraTotal > 0 then
                GameTooltip:AddLine(" ", 1, 1, 1)  -- spacer
                local exSc = SCHOOL_TEXT_COLORS[ttSchool] or SCHOOL_TEXT_COLORS["Physical"]
                GameTooltip:AddLine("Extra Attacks", exSc[1], exSc[2], exSc[3])
                -- Iterate sources; Lua 5.0 has no table.sort over keys, so use pairs
                for srcName, srcData in pairs(ttExtraSrc) do
                    for _, h in ipairs(srcData.hits) do
                        if h.isCrit then
                            GameTooltip:AddDoubleLine(srcName, tostring(h.amount),
                                0.85, 0.85, 0.85,
                                1.0, 0.85, 0.0)
                        else
                            GameTooltip:AddDoubleLine(srcName, tostring(h.amount),
                                0.85, 0.85, 0.85,
                                0.85, 0.85, 0.85)
                        end
                    end
                end
            end
            -- Total
            GameTooltip:AddLine(" ", 1, 1, 1)  -- spacer
            GameTooltip:AddDoubleLine("Total", ttDmg, 1, 1, 1, 1, 1, 1)
            GameTooltip:Show()
        end
        local function hideTT()
            doClear()
            GameTooltip:Hide()
        end

        bfr:SetScript("OnEnter",  function() showTT(bfr,  "ANCHOR_TOP")      end)
        bfr:SetScript("OnLeave",  function() hideTT() end)
        slot:SetScript("OnEnter", function() showTT(slot, "ANCHOR_TOPRIGHT") end)
        slot:SetScript("OnLeave", function() hideTT() end)
    end
end

local recapScrollFrame = CreateFrame("ScrollFrame", "TurtlePvPRecapScroll", recapFrame, "UIPanelScrollFrameTemplate")
recapScrollFrame:SetPoint("TOPLEFT",     recapFrame, "TOPLEFT",  8, -C.CHROME_TOP)
recapScrollFrame:SetPoint("BOTTOMRIGHT", recapFrame, "BOTTOMRIGHT", -24, C.CHROME_BOT)

local recapContent = CreateFrame("Frame", "TurtlePvPRecapContent", recapScrollFrame)
recapContent:SetWidth(480)
recapContent:SetHeight(1)
recapScrollFrame:SetScrollChild(recapContent)

local recapRowPool = {}
for _i = 1, 100 do
    local row = CreateFrame("Frame", nil, recapContent)
    row:SetWidth(C.CONTENT_W)
    row:SetHeight(C.LINE_H)

    -- Dark tint behind attacker name rows
    local cardBg = row:CreateTexture(nil, "BACKGROUND")
    cardBg:SetAllPoints(row)
    cardBg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    cardBg:SetVertexColor(0.07, 0.07, 0.09)
    cardBg:SetAlpha(0.85)
    cardBg:Hide()
    row.cardBg = cardBg

    -- Red left stripe (killing-blow attacker) — sits just right of the class icon
    local killLine = row:CreateTexture(nil, "BORDER")
    killLine:SetWidth(3)
    killLine:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    killLine:SetVertexColor(0.95, 0.15, 0.15)
    killLine:SetPoint("TOPLEFT",    row, "TOPLEFT",    C.ATTKBAR_ICON + 4, 0)
    killLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", C.ATTKBAR_ICON + 4, 0)
    killLine:Hide()
    row.killLine = killLine

    -- Separator line
    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sep:SetVertexColor(0.3, 0.28, 0.22)
    sep:SetAlpha(0.5)
    sep:SetPoint("LEFT",  row, "LEFT",  0, 0)
    sep:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    sep:Hide()
    row.sep = sep

    -- Portrait backing
    local portBg = row:CreateTexture(nil, "BORDER")
    portBg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    portBg:SetVertexColor(0.04, 0.04, 0.06)
    portBg:SetAlpha(0.9)
    portBg:Hide()
    row.portBg = portBg

    -- Rank badge icon (shown in attackerbar rows when BG score data is available)
    local rankIc = row:CreateTexture(nil, "OVERLAY")
    rankIc:Hide()
    row.rankIcon = rankIc

    -- Icon (portrait for attacker rows, spell icon for hit rows)
    local ic = row:CreateTexture(nil, "ARTWORK")
    ic:Hide()
    row.icon = ic

    -- Primary text (name / spell name / header)
    local fs = row:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    fs:SetJustifyH("LEFT")
    row.fs = fs

    -- Bar track
    local barBg = row:CreateTexture(nil, "ARTWORK")
    barBg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    barBg:SetVertexColor(0.10, 0.10, 0.13)
    barBg:SetAlpha(0.9)
    barBg:Hide()
    row.barBg = barBg

    -- Fill textures for per-school atkbar segments (one per spell slot)
    row.barFills = {}
    for fi = 1, C.STRIP_SLOTS do
        local bf = row:CreateTexture(nil, "OVERLAY")
        bf:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        bf:SetAlpha(0.92)
        bf:Hide()
        row.barFills[fi] = bf
    end
    -- Extra-attack (Windfury) sub-fill shown as a coloured right-hand portion of the fill
    row.wfFills = {}
    for fi = 1, C.STRIP_SLOTS do
        local wf = row:CreateTexture(nil, "OVERLAY")
        wf:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        wf:SetVertexColor(1, 1, 1)  -- overridden per-segment at render time
        wf:SetAlpha(0.75)
        wf:Hide()
        row.wfFills[fi] = wf
    end
    -- 1px yellow underline below the extra-attack strip (1px gap between it and the bar)
    row.wfUnderlines = {}
    for fi = 1, C.STRIP_SLOTS do
        local ul = row:CreateTexture(nil, "OVERLAY")
        ul:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        ul:SetVertexColor(1.0, 0.85, 0.10)
        ul:SetAlpha(0.90)
        ul:SetHeight(1)
        ul:Hide()
        row.wfUnderlines[fi] = ul
    end

    -- Transparent hit-frames over bar fills (textures can't receive mouse events)
    row.barFrames = {}
    for fi = 1, C.STRIP_SLOTS do
        local bfr = CreateFrame("Frame", nil, row)
        bfr:EnableMouse(false)
        bfr:SetFrameLevel(row:GetFrameLevel() + 2)
        bfr:Hide()
        row.barFrames[fi] = bfr
    end

    -- Damage number (right-aligned)
    local dmg = row:CreateFontString(nil, "OVERLAY")
    dmg:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    dmg:SetJustifyH("RIGHT")
    row.dmg = dmg

    -- BG scoreboard stats label (KB/Deaths/HK, top zone of attackerbar)
    local statFs = row:CreateFontString(nil, "OVERLAY")
    statFs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    statFs:SetJustifyH("LEFT")
    statFs:Hide()
    row.statFs = statFs

    -- Spell-strip slots: one per possible spell icon, shown horizontally
    row.slots = {}
    for si = 1, C.STRIP_SLOTS do
        local slot = CreateFrame("Frame", nil, row)
        slot:SetWidth(C.STRIP_STEP)
        slot:SetHeight(C.STRIP_H)
        slot:SetPoint("TOPLEFT", row, "TOPLEFT",
            C.STRIP_X + (si - 1) * C.STRIP_STEP, 0)
        slot:EnableMouse(false)

        local sic = slot:CreateTexture(nil, "ARTWORK")
        sic:SetWidth(C.STRIP_ICON)
        sic:SetHeight(C.STRIP_ICON)
        sic:SetPoint("LEFT", slot, "LEFT", 0, 0)  -- vertically centered in slot
        sic:Hide()
        slot.icon = sic

        local sdmg = slot:CreateFontString(nil, "OVERLAY")
        sdmg:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        sdmg:SetJustifyH("LEFT")
        sdmg:SetWidth(C.STRIP_STEP)
        sdmg:SetPoint("LEFT", sic, "RIGHT", 2, 0)
        sdmg:Hide()
        slot.dmg = sdmg

        -- Small Windfury badge (OVERLAY, top-left of spell icon) when WF procs are merged in
        local swfbadge = slot:CreateTexture(nil, "OVERLAY")
        swfbadge:SetTexture("Interface\\Icons\\spell_nature_windfury")
        swfbadge:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        swfbadge:SetWidth(10)
        swfbadge:SetHeight(10)
        swfbadge:Hide()
        slot.wfBadge = swfbadge

        slot:Hide()
        row.slots[si] = slot
    end

    row:Hide()
    table.insert(recapRowPool, row)
end

---------------------------------------------------------------------
-- Update the recap info tabs
---------------------------------------------------------------------
local function UpdateRecapTabs(recap)
    physTab:Hide()
    magTab:Hide()
    stunTab:Hide()
    stunTabIcon:Hide()

    if not recap or recap.noDamageData then return end

    local total = math.max(recap.totalDamage or 1, 1)

    -- Tally physical vs magic; aggregate per-spell totals for tooltips
    local physTotal, magTotal = 0, 0
    local physSpells, magSpells = {}, {}   -- {name=string, total=number, school=string}
    local physOrder, magOrder   = {}, {}
    for oi = 1, table.getn(recap.attackerOrder) do
        local grp = recap.attackerGroups[recap.attackerOrder[oi]]
        for hi = 1, table.getn(grp.hits) do
            local e = grp.hits[hi]
            local sName = e.spell or "Auto Attack"
            if e.school == "Physical" then
                physTotal = physTotal + e.amount
                if not physSpells[sName] then
                    physSpells[sName] = { name=sName, total=0, school=e.school }
                    table.insert(physOrder, sName)
                end
                physSpells[sName].total = physSpells[sName].total + e.amount
            else
                magTotal = magTotal + e.amount
                if not magSpells[sName] then
                    magSpells[sName] = { name=sName, total=0, school=e.school }
                    table.insert(magOrder, sName)
                end
                magSpells[sName].total = magSpells[sName].total + e.amount
            end
        end
    end
    -- Sort both lists by damage desc
    table.sort(physOrder, function(a,b) return physSpells[a].total > physSpells[b].total end)
    table.sort(magOrder,  function(a,b) return magSpells[a].total  > magSpells[b].total  end)

    local physPct = math.floor(physTotal / total * 100 + 0.5)
    local magPct  = math.floor(magTotal  / total * 100 + 0.5)

    -- Three tabs: Phys+Magic left, CC right
    -- Physical tab
    physTab.label:SetText("|cffd4722aPhysical|r |cffffaa22" .. physTotal .. "|r |cff888888(" .. physPct .. "%)|r")
    physTab:SetWidth(150)
    physTab:ClearAllPoints()
    physTab:SetPoint("TOPLEFT", recapFrame, "BOTTOMLEFT", 22, 6)
    physTab:EnableMouse(true)
    physTab:SetScript("OnEnter", function()
        GameTooltip:SetOwner(physTab, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Physical Damage", 0.831, 0.447, 0.165)
        if table.getn(physOrder) > 0 then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Sources:", 1, 0.82, 0)
            local physSc = SCHOOL_TEXT_COLORS["Physical"]
            for _, sName in ipairs(physOrder) do
                local sd = physSpells[sName]
                GameTooltip:AddDoubleLine(sName, tostring(sd.total),
                    0.85, 0.85, 0.85,
                    physSc[1], physSc[2], physSc[3])
            end
        end
        GameTooltip:Show()
    end)
    physTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    physTab:Show()

    -- Magic tab
    magTab.label:SetText("|cff5588ccMagic|r |cff44ccff" .. magTotal .. "|r |cff888888(" .. magPct .. "%)|r")
    magTab:SetWidth(150)
    magTab:ClearAllPoints()
    magTab:SetPoint("TOPLEFT", physTab, "TOPRIGHT", -4, 0)
    magTab:EnableMouse(true)
    magTab:SetScript("OnEnter", function()
        GameTooltip:SetOwner(magTab, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Magic Damage", 0.333, 0.533, 0.800)
        if table.getn(magOrder) > 0 then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Sources:", 1, 0.82, 0)
            for _, sName in ipairs(magOrder) do
                local sd = magSpells[sName]
                local sc = SCHOOL_TEXT_COLORS[sd.school] or SCHOOL_TEXT_COLORS["Physical"]
                GameTooltip:AddDoubleLine(sName, tostring(sd.total),
                    0.85, 0.85, 0.85,
                    sc[1], sc[2], sc[3])
            end
        end
        GameTooltip:Show()
    end)
    magTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    magTab:Show()

    -- Stun tab (top, whenever any CC was seen or totals recorded)
    local stunTotal = recap.stunTotal or 0
    local incTotal  = recap.incTotal  or 0
    local rootTotal = recap.rootTotal or 0
    local ttLines   = TBGH.lastRecap and TBGH.lastRecap.ccTtLines
    local hasTtLines = ttLines and table.getn(ttLines) > 0
    local hasTotals  = stunTotal > 0 or incTotal > 0 or rootTotal > 0
    if hasTtLines or hasTotals then
        -- Build label
        local ccStr = ""
        if stunTotal > 0 and incTotal > 0 then
            ccStr = string.format("%.1fs / %.1fs", stunTotal, incTotal)
        elseif stunTotal > 0 then
            ccStr = string.format("%.1fs", stunTotal)
        elseif incTotal > 0 then
            ccStr = string.format("%.1fs", incTotal)
        elseif rootTotal > 0 then
            ccStr = string.format("root %.1fs", rootTotal)
        elseif hasTtLines then
            ccStr = "CC x" .. table.getn(ttLines)
        else
            ccStr = "CC"
        end
        stunTab.label:ClearAllPoints()
        stunTab.label:SetPoint("CENTER", stunTab, "CENTER", 9, 2)
        stunTab.label:SetText(ccStr)
        stunTabIcon:ClearAllPoints()
        stunTabIcon:SetPoint("RIGHT", stunTab.label, "LEFT", -3, 0)
        stunTabIcon:Show()
        -- Auto-size: icon (14) + gap (3) + label width + left/right caps (32+32)
        local labelW = stunTab.label:GetStringWidth()
        stunTab:SetWidth(88)  -- minimum: caps(64) + icon(14) + gap(3) + "10.0s"(~24) fits at 88
        stunTab:ClearAllPoints()
        stunTab:SetPoint("TOPRIGHT", recapFrame, "BOTTOMRIGHT", -22, 6)
        -- Tooltip with individual CC entries
        stunTab:EnableMouse(true)
        stunTab:SetScript("OnEnter", function()
            GameTooltip:SetOwner(stunTab, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Crowd Control", 1, 0.82, 0)
            if ttLines then
                for ti = 1, table.getn(ttLines) do
                    local tl = ttLines[ti]
                    GameTooltip:AddDoubleLine(tl.name, tl.dur,
                        0.85, 0.85, 0.85,
                        1.0,  1.0,  1.0)
                end
            end
            GameTooltip:Show()
        end)
        stunTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
        stunTab:Show()
    end
end

---------------------------------------------------------------------
-- Populate and show the popup
---------------------------------------------------------------------
function TBGH:ShowRecapFrame()
    local recap = self.lastRecap
    if not recap then return end

    -- Update faction icon for the current player
    local faction = UnitFactionGroup("player")
    if faction == "Horde" then
        recapFactionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
    else
        recapFactionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
    end
    recapFactionIcon:SetTexCoord(0.09, 0.63, 0.05, 0.63)
    recapFactionFrame:Show()

    -- Sync the in-window "Always show" checkbox with the current db setting
    if self.db then
        recapAlwaysShowCheck:SetChecked(self.db.recapAutoExpand == true)
    end

    local lines = BuildRecapLines(recap)
    self:RecapAddLog("[RecapDebug] ShowRecapFrame: " .. table.getn(lines) .. " lines, nAtk=" .. table.getn(recap.attackerOrder or {}))

    UpdateRecapTabs(recap)

    for pi = 1, table.getn(recapRowPool) do
        recapRowPool[pi]:Hide()
    end

    -- Total pixel height
    local totalH = 0
    for i = 1, table.getn(lines) do
        local lt = lines[i].lineType
        if     lt == "sep"        then totalH = totalH + C.SEP_H
        elseif lt == "attacker"   then totalH = totalH + C.ATTK_H
        elseif lt == "attackerbar" then totalH = totalH + C.ATTKBAR_H
        elseif lt == "atkbar"     then totalH = totalH + C.ATKBAR_H
        elseif lt == "spellstrip" then totalH = totalH + C.STRIP_H
        else                           totalH = totalH + C.LINE_H end
    end
    recapContent:SetHeight(math.max(totalH, 1))

    -- Dynamic frame sizing: grow to fit content, cap at C.MAX_ATTACKERS worth
    local atkBlockH   = C.ATTKBAR_H + C.SEP_H  -- 57px per attacker block
    local maxContentH = C.MAX_ATTACKERS * atkBlockH + C.LINE_H
    local needsScroll = totalH > maxContentH
    local visContentH = needsScroll and maxContentH or totalH
    local newFrameH   = math.max(visContentH + C.CHROME_TOP + C.CHROME_BOT, 80)
    recapFrame:SetHeight(newFrameH)

    -- Show/hide scrollbar and widen scroll area when not needed
    local scrollBar = TurtlePvPRecapScrollScrollBar
    recapScrollFrame:ClearAllPoints()
    recapScrollFrame:SetPoint("TOPLEFT", recapFrame, "TOPLEFT", 8, -C.CHROME_TOP)
    if needsScroll then
        recapScrollFrame:SetPoint("BOTTOMRIGHT", recapFrame, "BOTTOMRIGHT", -24, C.CHROME_BOT)
        if scrollBar then scrollBar:Show() end
    else
        recapScrollFrame:SetPoint("BOTTOMRIGHT", recapFrame, "BOTTOMRIGHT", -8, C.CHROME_BOT)
        if scrollBar then scrollBar:Hide() end
        recapScrollFrame:SetVerticalScroll(0)
    end

    local yOff = 0
    for i = 1, table.getn(lines) do
        local ln  = lines[i]
        local row = recapRowPool[i]
        if not row then break end

        local lt = ln.lineType
        local rowH
        if     lt == "sep"         then rowH = C.SEP_H
        elseif lt == "attacker"    then rowH = C.ATTK_H
        elseif lt == "attackerbar" then rowH = C.ATTKBAR_H
        elseif lt == "atkbar"      then rowH = C.ATKBAR_H
        elseif lt == "spellstrip"  then rowH = C.STRIP_H
        else                            rowH = C.LINE_H end

        row:SetHeight(rowH)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", recapContent, "TOPLEFT", 0, -yOff)
        yOff = yOff + rowH

        -- Reset all sub-elements
        row.cardBg:Hide()
        row.killLine:Hide()
        row.sep:Hide()
        row.portBg:Hide()
        row.icon:Hide()
        row.rankIcon:Hide()
        row.barBg:Hide()
        if row.barFills then
            for fi = 1, C.STRIP_SLOTS do row.barFills[fi]:Hide() end
        end
        if row.wfFills then
            for fi = 1, C.STRIP_SLOTS do row.wfFills[fi]:Hide() end
        end
        if row.wfUnderlines then
            for fi = 1, C.STRIP_SLOTS do row.wfUnderlines[fi]:Hide() end
        end
        if row.barFrames then
            for fi = 1, C.STRIP_SLOTS do
                local bfr = row.barFrames[fi]
                bfr:Hide()
                bfr:EnableMouse(false)
                bfr:SetScript("OnEnter", nil)
                bfr:SetScript("OnLeave", nil)
            end
        end
        row.fs:SetText("")
        row.dmg:SetText("")
        if row.statFs then row.statFs:Hide() end
        row:EnableMouse(false)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        if row.slots then
            for si = 1, C.STRIP_SLOTS do
                local slot = row.slots[si]
                slot:Hide()
                slot:EnableMouse(false)
                slot:SetScript("OnEnter", nil)
                slot:SetScript("OnLeave", nil)
            end
        end

        if lt == "sep" then
            -- No visible separator line; row is just a thin spacing gap
            row.sep:Hide()

        elseif lt == "attacker" then
            row.cardBg:Show()
            if ln.isKill then row.killLine:Show() end
            -- Portrait
            if ln.iconTex then
                row.portBg:ClearAllPoints()
                row.portBg:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -1)
                row.portBg:SetWidth(C.ICON_SIZE + 2)
                row.portBg:SetHeight(C.ICON_SIZE + 2)
                row.portBg:Show()
                row.icon:ClearAllPoints()
                row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -2)
                row.icon:SetWidth(C.ICON_SIZE)
                row.icon:SetHeight(C.ICON_SIZE)
                row.icon:SetTexture(ln.iconTex)
                if ln.iconCoords then
                    row.icon:SetTexCoord(
                        ln.iconCoords[1], ln.iconCoords[2],
                        ln.iconCoords[3], ln.iconCoords[4])
                else
                    row.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
                end
                row.icon:Show()
            end
            -- Name
            row.fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            row.fs:ClearAllPoints()
            row.fs:SetPoint("LEFT", row, "LEFT", C.NAME_X, 0)
            row.fs:SetText(ln.text)
            row.fs:SetTextColor(ln.r, ln.g, ln.b)
            -- Total damage
            row.dmg:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            row.dmg:ClearAllPoints()
            row.dmg:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.dmg:SetWidth(C.DMG_W)
            row.dmg:SetText(tostring(ln.totalDmg))
            if ln.isKill then
                row.dmg:SetTextColor(1.0, 0.35, 0.35)
            else
                row.dmg:SetTextColor(1, 1, 1)
            end

        elseif lt == "attackerbar" then
            -- Single merged row: [ClassIcon][Name/Stats] [▓fill▓ icon|dmg ▓fill▓ icon|dmg ...] [total]
            -- Each bar segment is a semi-transparent full-height fill; spell icon overlays at left edge.
            local rowH   = C.ATTKBAR_H
            local iconSz = rowH - 10  -- spell icon: 4px pad each side
            -- Class icon (left zone, vertically centered)
            if ln.iconTex then
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
                row.icon:SetWidth(C.ATTKBAR_ICON)
                row.icon:SetHeight(C.ATTKBAR_ICON)
                row.icon:SetTexture(ln.iconTex)
                if ln.iconCoords then
                    row.icon:SetTexCoord(
                        ln.iconCoords[1], ln.iconCoords[2],
                        ln.iconCoords[3], ln.iconCoords[4])
                else
                    row.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
                end
                row.icon:Show()
            end
            -- Left zone layout:
            --   Top half:    [ClassIcon top]  [Name centered in top half]
            --   Bottom half: [RankIcon at BL of ClassIcon]  [K/D/A centered in bottom half]
            local halfY    = math.floor(rowH / 4)  -- offset from row center to half-band center
            local nameX    = C.ATTKBAR_ICON + 5
            local nameW    = C.ATTKBAR_BX - C.ATTKBAR_ICON - 8
            local bs       = ln.bgStats
            -- Name: top-aligned with the top of the class icon
            local iconTopY = math.floor(C.ATTKBAR_ICON / 2)  -- offset from row center to icon top
            row.fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            row.fs:ClearAllPoints()
            row.fs:SetPoint("TOPLEFT", row, "LEFT", nameX, iconTopY)
            row.fs:SetWidth(nameW)
            row.fs:SetJustifyH("LEFT")
            row.fs:SetText(ln.text)
            row.fs:SetTextColor(ln.r, ln.g, ln.b)
            -- Rank icon: bottom-left corner of the class icon
            local RANK_SZ = 14
            if bs and bs.rank and bs.rank > 0 then
                local rankNum = string.format("%02d", bs.rank)
                row.rankIcon:SetTexture("Interface\\PvPRankBadges\\PvPRank" .. rankNum)
                row.rankIcon:ClearAllPoints()
                row.rankIcon:SetPoint("CENTER", row.icon, "BOTTOMRIGHT", 0, 0)
                row.rankIcon:SetWidth(RANK_SZ)
                row.rankIcon:SetHeight(RANK_SZ)
                row.rankIcon:Show()
            else
                row.rankIcon:Hide()
                RANK_SZ = 0
            end
            -- K/D/A: centered in bottom half, starts right of rank icon (or nameX if no rank)
            if bs then
                local kdaX = nameX + (RANK_SZ > 0 and RANK_SZ - 2 or 0)
                local statTxt = string.format("|cffaaaaaa%d/%d/%d|r",
                    bs.kbs or 0, bs.deaths or 0, bs.hks or 0)
                row.statFs:ClearAllPoints()
                row.statFs:SetPoint("LEFT", row, "LEFT", kdaX, -halfY)
                row.statFs:SetWidth(nameW)
                row.statFs:SetText(statTxt)
                row.statFs:Show()
            else
                row.statFs:Hide()
            end
            -- Bar fills + spell slot overlays (unified loop)
            local spells   = ln.spells or {}
            local rawCount = table.getn(spells)
            local totalDmg = math.max(ln.totalDmg or 1, 1)
            local barW     = math.floor(C.ATTKBAR_BW * (ln.barFrac or 1))
            local GAP      = 2  -- px gap between spell segments
            local otherDmg = 0
            if rawCount > CAP then
                for oi = CAP + 1, rawCount do
                    otherDmg = otherDmg + (spells[oi].dmgAmt or 0)
                end
            end
            local hasOther = (otherDmg > 0)
            local nSpells  = math.min(rawCount, CAP) + (hasOther and 1 or 0)
            local totalGap = math.max(nSpells - 1, 0) * GAP
            -- Icons overlay on top of their segment fill; fills share the full barW
            local fillW    = math.max(barW - totalGap, 1)
            local xCursor  = C.ATTKBAR_BX
            local fillBaseR, fillBaseG, fillBaseB = {}, {}, {}
            local cumDmg = 0  -- running sum for cumulative-pixel width calculation
            for fi = 1, nSpells do
                local sp
                local isOther = (hasOther and fi == nSpells)
                if isOther then
                    sp = { dmgAmt=otherDmg, school="Physical",
                           dmgText=tostring(otherDmg), isCrit=false,
                           icon=nil }
                else
                    sp = spells[fi]
                end
                local sc   = isOther and {0.50,0.50,0.50}
                              or (SCHOOL_COLORS[sp.school] or SCHOOL_COLORS["Physical"])
                -- Cumulative pixel positions avoid accumulated floor() rounding errors
                local prevPx = math.floor(fillW * cumDmg / totalDmg)
                cumDmg = cumDmg + sp.dmgAmt
                local nextPx = math.floor(fillW * cumDmg / totalDmg)
                -- Enforce a minimum so the bar colour is visible beyond the icon overlay
                local minSeg = isOther and 16 or (iconSz + 16)
                local segW = math.max(nextPx - prevPx, minSeg)
                local cr, cg, cb = sc[1], sc[2], sc[3]
                fillBaseR[fi], fillBaseG[fi], fillBaseB[fi] = cr, cg, cb
                -- Bar fill spans the full segment width; icon overlays the left portion
                local iconBotBase = math.floor((rowH - iconSz) / 2)
                local segH    = sp.isCrit and iconSz or math.floor(iconSz * 2 / 3)
                local iconBot = iconBotBase
                local slotW = isOther and 0 or iconSz
                -- Split fill: main portion + optional brighter same-school portion at right end
                local wfSubW = 0
                local wfFill = row.wfFills[fi]
                if not isOther and sp.extraTotal and sp.extraTotal > 0 then
                    local rawFrac = sp.extraTotal / math.max(sp.dmgAmt, 1)
                    wfSubW = math.max(math.floor(segW * rawFrac), 4)
                    -- Cap so there's always at least 4px of main fill
                    wfSubW = math.min(wfSubW, segW - 5)
                    -- Same school color and alpha as main fill; gold underline is the only cue
                    local er, eg, eb = cr, cg, cb
                    wfFill:SetVertexColor(er, eg, eb)
                    wfFill:ClearAllPoints()
                    wfFill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", xCursor + segW - wfSubW, iconBot)
                    wfFill:SetWidth(wfSubW)
                    wfFill:SetHeight(segH)
                    wfFill:SetAlpha(0.55)
                    wfFill:Show()
                    -- 1px yellow underline, 1px gap below the fill
                    local ul = row.wfUnderlines[fi]
                    ul:ClearAllPoints()
                    ul:SetPoint("TOPLEFT", row, "BOTTOMLEFT", xCursor + segW - wfSubW, iconBot - 2)
                    ul:SetWidth(wfSubW)
                    ul:Show()
                else
                    wfFill:Hide()
                    row.wfUnderlines[fi]:Hide()
                end
                local mainW = segW - wfSubW - (wfSubW > 0 and 1 or 0)  -- 1px gap when WF present
                local bf = row.barFills[fi]
                bf:ClearAllPoints()
                bf:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", xCursor, iconBot)
                bf:SetWidth(math.max(mainW, 1))
                bf:SetHeight(segH)
                bf:SetVertexColor(cr, cg, cb)
                bf:SetAlpha(0.55)
                bf:Show()
                -- Hover frame covers the full segment
                local bfr = row.barFrames[fi]
                bfr:ClearAllPoints()
                bfr:SetPoint("TOPLEFT", row, "TOPLEFT", xCursor, 0)
                bfr:SetWidth(segW)
                bfr:SetHeight(rowH)
                bfr:EnableMouse(true)
                bfr:Show()
                -- Slot frame (icon overlaid at left of segment; zero-width for Other)
                local slot = row.slots[fi]
                slot:ClearAllPoints()
                slot:SetPoint("TOPLEFT", row, "TOPLEFT", xCursor, 0)
                slot:SetWidth(math.max(slotW, 1))
                slot:SetHeight(rowH)
                if isOther then
                    slot.icon:Hide()
                elseif sp.icon then
                    slot.icon:SetTexture(sp.icon)
                    slot.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
                else
                    slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    slot.icon:SetTexCoord(0, 1, 0, 1)
                end
                if not isOther then
                    slot.icon:SetWidth(iconSz)
                    slot.icon:SetHeight(iconSz)
                    slot.icon:Show()
                end
                -- Damage number: after icon, vertically centered on the bar fill
                local dmgX = xCursor + slotW + 2
                local dmgY = iconBot + math.floor(segH / 2) - math.floor(rowH / 2)
                slot.dmg:ClearAllPoints()
                slot.dmg:SetPoint("LEFT", row, "LEFT", dmgX, dmgY)
                slot.dmg:SetJustifyH("LEFT")
                local tsc = isOther and {0.75,0.75,0.75}
                             or (SCHOOL_TEXT_COLORS[sp.school] or SCHOOL_TEXT_COLORS["Physical"])
                local dr, dg, db = tsc[1], tsc[2], tsc[3]
                -- Only show number if there's room after the icon
                if segW - slotW >= 20 then
                    slot.dmg:SetText(sp.dmgText)
                    slot.dmg:SetTextColor(dr, dg, db)
                    slot.dmg:Show()
                else
                    slot.dmg:Hide()
                end
                -- WF badge replaced by bar coloring; keep hidden
                if slot.wfBadge then slot.wfBadge:Hide() end
                slot:EnableMouse(true)
                slot:Show()
                xCursor = xCursor + segW + GAP
            end  -- for fi
            row.dmg:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            row.dmg:ClearAllPoints()
            row.dmg:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.dmg:SetWidth(C.CONTENT_W - C.ATTKBAR_BX - C.ATTKBAR_BW - 12)
            row.dmg:SetJustifyH("RIGHT")
            row.dmg:SetText(tostring(ln.totalDmg))
            if ln.isKill then
                row.dmg:SetTextColor(1.0, 0.35, 0.35)
            else
                row.dmg:SetTextColor(0.85, 0.85, 0.85)
            end
            -- Cross-highlight wiring
            WireBarHighlight(row.barFills, row.barFrames, row.slots, nSpells, spells, row.wfFills)

        elseif lt == "atkbar" then
            -- Per-spell school-colored segments, same left-to-right order as spellstrip
            local spells   = ln.spells or {}
            local totalDmg = math.max(ln.totalDmg or 1, 1)
            local barW     = math.floor(C.ATKBAR_W * (ln.barFrac or 1))
            row.barBg:ClearAllPoints()
            row.barBg:SetPoint("LEFT", row, "LEFT", C.ATKBAR_X, 0)
            row.barBg:SetWidth(C.ATKBAR_W)
            row.barBg:SetHeight(C.ATKBAR_H2)
            row.barBg:Show()
            -- Total damage label after the bar
            row.dmg:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            row.dmg:ClearAllPoints()
            row.dmg:SetPoint("LEFT", row, "LEFT", C.ATKBAR_X + C.ATKBAR_W + 4, 0)
            row.dmg:SetWidth(C.DMG_W - 4)
            row.dmg:SetJustifyH("LEFT")
            row.dmg:SetText(tostring(ln.totalDmg))
            row.dmg:SetTextColor(0.75, 0.75, 0.75)
            local GAP      = 2  -- px gap between segments
            local nSpells  = math.min(table.getn(spells), C.STRIP_SLOTS)
            -- shrink barW to leave room for gaps between segments
            local totalGap = math.max(nSpells - 1, 0) * GAP
            local fillW    = math.max(barW - totalGap, 1)
            local xCursor  = C.ATKBAR_X
            for fi = 1, nSpells do
                local sp   = spells[fi]
                local sc   = SCHOOL_COLORS[sp.school] or SCHOOL_COLORS["Physical"]
                local segW = math.max(math.floor(fillW * sp.dmgAmt / totalDmg), 1)
                local bf   = row.barFills[fi]
                bf:ClearAllPoints()
                bf:SetPoint("LEFT", row, "LEFT", xCursor, 0)
                bf:SetWidth(segW)
                bf:SetHeight(C.ATKBAR_H2)
                bf:SetVertexColor(sc[1], sc[2], sc[3])
                bf:Show()
                xCursor = xCursor + segW + GAP
            end

        elseif lt == "spellstrip" then
            local spells = ln.spells or {}
            for si = 1, C.STRIP_SLOTS do
                local slot = row.slots[si]
                local sp   = spells[si]
                if sp then
                    if sp.icon then
                        slot.icon:SetTexture(sp.icon)
                        slot.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
                    else
                        slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        slot.icon:SetTexCoord(0, 1, 0, 1)
                    end
                    slot.icon:Show()
                    local sc = SCHOOL_TEXT_COLORS[sp.school] or SCHOOL_TEXT_COLORS["Physical"]
                    local dr, dg, db = sc[1], sc[2], sc[3]
                    slot.dmg:SetText(sp.dmgText)
                    slot.dmg:SetTextColor(dr, dg, db)
                    slot.dmg:Show()
                    -- Per-slot tooltip
                    local ttName   = sp.name
                    local ttSchool = sp.school
                    local ttDmg    = sp.dmgText
                    local ttCount  = sp.hitCount
                    local ttCrit   = sp.isCrit
                    slot:EnableMouse(true)
                    slot:SetScript("OnEnter", function()
                        GameTooltip:SetOwner(slot, "ANCHOR_TOPRIGHT")
                        GameTooltip:ClearLines()
                        GameTooltip:AddLine(ttName, 1, 1, 1)
                        local sc2 = SCHOOL_TEXT_COLORS[ttSchool] or SCHOOL_TEXT_COLORS["Physical"]
                        GameTooltip:AddLine(ttSchool .. " damage", sc2[1], sc2[2], sc2[3])
                        GameTooltip:AddLine("Total:  " .. ttDmg, 0.9, 0.9, 0.9)
                        if ttCount > 1 then
                            local avg = math.floor((tonumber(ttDmg) or 0) / ttCount)
                            GameTooltip:AddLine(ttCount .. " hits   avg " .. avg, 0.65, 0.65, 0.65)
                        end
                        if ttCrit then
                            GameTooltip:AddLine("Includes critical strikes", 1, 0.82, 0)
                        end
                        GameTooltip:Show()
                    end)
                    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    slot:Show()
                end
            end

        else  -- "header" / "text" / "ccsummary"
            row.fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            row.fs:ClearAllPoints()
            row.fs:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.fs:SetWidth(C.CONTENT_W - 8)
            row.fs:SetText(ln.text or "")
            row.fs:SetTextColor(ln.r or 1, ln.g or 1, ln.b or 1)
            if lt == "ccsummary" and ln.tooltipLines then
                local ttLines = ln.tooltipLines
                row:EnableMouse(true)
                row:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(row, "ANCHOR_TOPRIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine("Crowd Control", 1, 0.82, 0)
                    for ti = 1, table.getn(ttLines) do
                        local tl = ttLines[ti]
                        if type(tl) == "table" then
                            GameTooltip:AddDoubleLine(tl.name, tl.dur,
                                0.85, 0.85, 0.85,
                                1.0,  1.0,  1.0)
                        else
                            GameTooltip:AddLine(tl, 1, 1, 1)
                        end
                    end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end

        row:Show()
    end

    recapScrollFrame:SetVerticalScroll(0)
    recapFrame:Show()
end

---------------------------------------------------------------------
-- Mockup: inject synthetic recap data and open the frame
-- Usage: /tpvp mockup
---------------------------------------------------------------------
function TBGH:ShowMockupRecap()
    -- Inject fake BG score cache  (kbs / deaths / hks / rank / faction)
    self.bgScoreCache = self.bgScoreCache or {}
    self.bgScoreCache["Grimtusk"]  = { kbs=5, deaths=0, hks=31, rank=10, faction=1 }
    self.bgScoreCache["Shadowvex"] = { kbs=3, deaths=1, hks=19, rank=7,  faction=1 }
    self.bgScoreCache["Hexblight"] = { kbs=1, deaths=3, hks=9,  rank=3,  faction=1 }
    self.bgScoreCache["Aelindra"]  = { kbs=2, deaths=2, hks=14, rank=5,  faction=0 }
    self.bgScoreCache["Frostbane"] = { kbs=0, deaths=5, hks=4,  rank=2,  faction=0 }

    -- Build a flat hits array from a spell descriptor list.
    -- Returns (hits, killHit) where killHit is the first hit of killSpell (or nil).
    local function makeHits(spells, killSpell)
        local hits, killHit = {}, nil
        for _, s in ipairs(spells) do
            for h = 1, s.hitCount do
                local hit = {
                    amount  = math.floor(s.dmgAmt / s.hitCount),
                    school  = s.school,
                    spell   = s.name,
                    hitType = s.isCrit and "crit" or "hit",
                }
                table.insert(hits, hit)
                if killHit == nil and s.name == killSpell then killHit = hit end
            end
        end
        return hits, killHit
    end

    -- ── Attacker 1: Grimtusk (Warrior, Rank 10) — killing blow ────────────────
    -- Auto Attack absorbs 2× Windfury and 1× Sword Spec procs (extra-attack merge)
    local a1spells = {
        { name="Mortal Strike",        school="Physical", dmgAmt=1842, isCrit=true,  hitCount=1 },
        { name="Whirlwind",            school="Physical", dmgAmt=1020, isCrit=false, hitCount=3 },
        { name="Auto Attack",          school="Physical", dmgAmt= 740, isCrit=false, hitCount=5 },
        { name="Master Strike",        school="Physical", dmgAmt= 480, isCrit=true,  hitCount=1 },
        { name="Windfury Attack",      school="Physical", dmgAmt= 310, isCrit=true,  hitCount=2 },
        { name="Sword Specialization", school="Physical", dmgAmt= 148, isCrit=false, hitCount=1 },
    }
    local a1total = 0
    for _, s in ipairs(a1spells) do a1total = a1total + s.dmgAmt end
    local a1hits, a1killHit = makeHits(a1spells, "Mortal Strike")

    -- ── Attacker 2: Shadowvex (Rogue, Rank 7) ─────────────────────────────────
    local a2spells = {
        { name="Backstab",       school="Physical", dmgAmt=1140, isCrit=true,  hitCount=1 },
        { name="Sinister Strike",school="Physical", dmgAmt= 680, isCrit=false, hitCount=5 },
        { name="Hemorrhage",     school="Physical", dmgAmt= 320, isCrit=false, hitCount=3 },
        { name="Rupture",        school="Physical", dmgAmt= 210, isCrit=false, hitCount=6 },
    }
    local a2total = 0
    for _, s in ipairs(a2spells) do a2total = a2total + s.dmgAmt end
    local a2hits = makeHits(a2spells)

    -- ── Attacker 3: Hexblight (Warlock, Rank 3) ───────────────────────────────
    -- 6 spells — Curse of Agony overflows into "Other" bucket
    local a3spells = {
        { name="Shadow Bolt",    school="Shadow", dmgAmt= 780, isCrit=true,  hitCount=1 },
        { name="Corruption",     school="Shadow", dmgAmt= 350, isCrit=false, hitCount=5 },
        { name="Searing Pain",   school="Fire",   dmgAmt= 240, isCrit=false, hitCount=2 },
        { name="Drain Life",     school="Shadow", dmgAmt= 180, isCrit=false, hitCount=3 },
        { name="Immolate",       school="Fire",   dmgAmt= 140, isCrit=false, hitCount=3 },
        { name="Curse of Agony", school="Shadow", dmgAmt=  85, isCrit=false, hitCount=6 },
    }
    local a3total = 0
    for _, s in ipairs(a3spells) do a3total = a3total + s.dmgAmt end
    local a3hits = makeHits(a3spells)

    -- ── Attacker 4: Aelindra (Hunter, Rank 5) ─────────────────────────────────
    -- 2× Extra Shot procs merged into Auto Shot
    local a4spells = {
        { name="Aimed Shot",   school="Physical", dmgAmt= 620, isCrit=true,  hitCount=1 },
        { name="Auto Shot",    school="Physical", dmgAmt= 480, isCrit=false, hitCount=4 },
        { name="Multi-Shot",   school="Physical", dmgAmt= 310, isCrit=false, hitCount=1 },
        { name="Serpent Sting",school="Nature",   dmgAmt= 210, isCrit=false, hitCount=5 },
        { name="Extra Shot",   school="Physical", dmgAmt= 190, isCrit=false, hitCount=2 },
    }
    local a4total = 0
    for _, s in ipairs(a4spells) do a4total = a4total + s.dmgAmt end
    local a4hits = makeHits(a4spells)

    -- ── Attacker 5: Frostbane (Mage, Rank 2) ──────────────────────────────────
    local a5spells = {
        { name="Frostbolt",      school="Frost",  dmgAmt= 540, isCrit=true,  hitCount=1 },
        { name="Cone of Cold",   school="Frost",  dmgAmt= 310, isCrit=false, hitCount=1 },
        { name="Arcane Missiles",school="Arcane", dmgAmt= 220, isCrit=false, hitCount=5 },
        { name="Frost Nova",     school="Frost",  dmgAmt=  42, isCrit=false, hitCount=1 },
    }
    local a5total = 0
    for _, s in ipairs(a5spells) do a5total = a5total + s.dmgAmt end
    local a5hits = makeHits(a5spells)

    -- ── Synthetic recap ────────────────────────────────────────────────────────
    local fakeRecap = {
        noDamageData  = false,
        maxHP         = 4800,
        attackerOrder = { "Grimtusk", "Shadowvex", "Hexblight", "Aelindra", "Frostbane" },
        attackerClass = {
            ["Grimtusk"]  = "WARRIOR",
            ["Shadowvex"] = "ROGUE",
            ["Hexblight"] = "WARLOCK",
            ["Aelindra"]  = "HUNTER",
            ["Frostbane"] = "MAGE",
        },
        attackerGroups = {
            ["Grimtusk"]  = { total=a1total, hits=a1hits },
            ["Shadowvex"] = { total=a2total, hits=a2hits },
            ["Hexblight"] = { total=a3total, hits=a3hits },
            ["Aelindra"]  = { total=a4total, hits=a4hits },
            ["Frostbane"] = { total=a5total, hits=a5hits },
        },
        killingEntry = a1killHit,
        -- CC snapshot: durations stay within 0–15s sanity clamp
        snapshot = {
            { isCC=true, ccName="Cheap Shot",  time=0,  ccEnd=1.5  },
            { isCC=true, ccName="Kidney Shot", time=3,  ccEnd=6.5  },
            { isCC=true, ccName="Frost Nova",  time=9,  ccEnd=12.0 },
        },
        stunTotal = 0, incTotal = 0, rootTotal = 0, ccTtLines = nil,
    }

    -- Seed class cache so portrait icons appear immediately
    self.classCache = self.classCache or {}
    self.classCache["Grimtusk"]  = "WARRIOR"
    self.classCache["Shadowvex"] = "ROGUE"
    self.classCache["Hexblight"] = "WARLOCK"
    self.classCache["Aelindra"]  = "HUNTER"
    self.classCache["Frostbane"] = "MAGE"

    self.lastRecap = fakeRecap
    self:ShowRecapFrame()
end

local recapExportFrame    = nil
local missingIconsFrame   = nil

function TBGH:ShowMissingIconsFrame()
    if not missingIconsFrame then
        local f = CreateFrame("Frame", "TurtlePvPMissingIconsFrame", UIParent)
        f:SetWidth(480)
        f:SetHeight(320)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", f, "TOP", 0, -10)
        title:SetText("|cffffd100Spells Missing Icons|r")

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOP", f, "TOP", 0, -26)
        hint:SetText("|cffaaaaaa Click the box, Ctrl+A to select all, Ctrl+C to copy|r")

        local closeBtn = CreateFrame("Button", "TurtlePvPMissingIconsClose", f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

        local sf = CreateFrame("ScrollFrame", "TurtlePvPMissingIconsScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT",     f, "TOPLEFT",     16, -44)
        sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 12)

        local eb = CreateFrame("EditBox", "TurtlePvPMissingIconsEditBox", sf)
        eb:SetMultiLine(true)
        eb:SetMaxLetters(0)
        eb:SetWidth(420)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(false)
        eb:EnableMouse(true)
        sf:SetScrollChild(eb)

        missingIconsFrame     = f
        missingIconsFrame._eb = eb
    end

    local list = {}
    for name, _ in pairs(TBGH.db.missingIcons or {}) do
        table.insert(list, name)
    end
    table.sort(list)

    local text = ""
    if table.getn(list) == 0 then
        text = "(none recorded yet — take some damage first)"
    else
        for i = 1, table.getn(list) do
            text = text .. list[i] .. "\n"
        end
    end
    missingIconsFrame._eb:SetText(text)
    missingIconsFrame:Show()
end

function TBGH:ShowRecapExportFrame()
    if not recapExportFrame then
        local f = CreateFrame("Frame", "TurtlePvPExportFrame", UIParent)
        f:SetWidth(640)
        f:SetHeight(400)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", f, "TOP", 0, -10)
        title:SetText("|cffffd100TurtlePvP Debug Log|r")

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOP", f, "TOP", 0, -26)
        hint:SetText("|cffaaaaaa Click the box, Ctrl+A to select all, Ctrl+C to copy|r")

        local closeBtn = CreateFrame("Button", "TurtlePvPExportClose", f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

        local sf = CreateFrame("ScrollFrame", "TurtlePvPExportScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT",     f, "TOPLEFT",     16, -44)
        sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 12)

        local eb = CreateFrame("EditBox", "TurtlePvPExportEditBox", sf)
        eb:SetMultiLine(true)
        eb:SetMaxLetters(0)
        eb:SetWidth(580)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(false)
        eb:EnableMouse(true)
        sf:SetScrollChild(eb)

        recapExportFrame      = f
        recapExportFrame._eb  = eb
    end

    -- Build text from log ring buffer
    local log   = self.recapLog
    local parts = {}
    for i = 1, table.getn(log) do
        parts[i] = log[i]
    end
    local text = ""
    for i = 1, table.getn(parts) do
        text = text .. parts[i] .. "\n"
    end
    if text == "" then
        text = "(no log entries yet — enable recapdebug or take some damage first)"
    end
    recapExportFrame._eb:SetText(text)
    recapExportFrame:Show()
end

---------------------------------------------------------------------
-- Settings module registration
---------------------------------------------------------------------
TBGH:RegisterModule({
    name = "recap",
    tab  = "combat",

    buildSettings = function(parent, prevFrame)
        local f = TBGH.CreateSectionFrame(parent, prevFrame, "Death Recap", "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")

        local enableCheck = CreateFrame("CheckButton", "TurtlePvPRecapEnableCheck", f, "UICheckButtonTemplate")
        enableCheck:SetWidth(24)
        enableCheck:SetHeight(24)
        enableCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -26)
        local enableLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 2, 0)
        enableLabel:SetText("Enable death recap")

        local expandCheck = CreateFrame("CheckButton", "TurtlePvPRecapExpandCheck", f, "UICheckButtonTemplate")
        expandCheck:SetWidth(20)
        expandCheck:SetHeight(20)
        expandCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 16, 2)
        local expandLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        expandLabel:SetPoint("LEFT", expandCheck, "RIGHT", 2, 0)
        expandLabel:SetText("Always expand on death")

        f:SetHeight(80)

        local function SyncExpandState(enabled)
            if enabled then
                expandCheck:Enable()
                expandLabel:SetTextColor(1, 1, 1)
            else
                expandCheck:Disable()
                expandLabel:SetTextColor(0.5, 0.5, 0.5)
            end
        end

        enableCheck:SetScript("OnClick", function()
            local checked = this:GetChecked() and true or false
            TBGH.db.recapEnabled = checked
            SyncExpandState(checked)
        end)
        expandCheck:SetScript("OnClick", function()
            TBGH.db.recapAutoExpand = this:GetChecked() and true or false
        end)

        TBGH._recapEnableCheck  = enableCheck
        TBGH._recapExpandCheck  = expandCheck
        TBGH._recapExpandLabel  = expandLabel
        TBGH._syncRecapExpand   = SyncExpandState
        return f
    end,

    syncSettings = function()
        local db = TBGH.db
        if TBGH._recapEnableCheck then
            local enabled = db.recapEnabled ~= false
            TBGH._recapEnableCheck:SetChecked(enabled)
            TBGH._recapExpandCheck:SetChecked(db.recapAutoExpand == true)
            if TBGH._syncRecapExpand then TBGH._syncRecapExpand(enabled) end
        end
    end,
})
