-- name: Squishy Radio
-- description: A Music Player built into CoopDX

--- @class MusicPlayerData
--- @field public name string Song Name
--- @field public artist string Song Artist
--- @field public stream ModAudio 
--- @field public loopA integer Where your music starts looping in seconds
--- @field public loopB integer Where your music stops looping in seconds
--- @field public length integer The duration of the song in seconds
--- @field public bpm integer Where your music stops looping

function num_wrap(num, min, max)
    return min + (num - min) % ((max + 1) - min)
end

---@param string string
--- Splits a string into a table by spaces
function string_split(string, splitAt)
    if splitAt == nil then
        splitAt = " "
    end
    local result = {}
    for match in string:gmatch(string.format("[^%s]+", splitAt)) do
        table.insert(result, match)
    end
    return result
end

function string_endswith(s, suffix)
    return string.sub(s, 1 + #s - #suffix) == suffix
end

local secondaryTargetVolume = 1
local secondaryTargetFadeTimer = 0
local secondaryTargetFadeTarget = 1
local secondaryTargetFadeOut = true
local og_play_secondary_music = play_secondary_music
_G.play_secondary_music = function(seqID, bgMusicVolume, volume, fadeTimer)
    secondaryTargetVolume = bgMusicVolume
    secondaryTargetFadeTimer = secondaryTargetFadeOut and secondaryTargetFadeTimer or 0
    secondaryTargetFadeTarget = fadeTimer
    secondaryTargetFadeOut = true

    og_play_secondary_music(seqID, bgMusicVolume, volume, fadeTimer)
end

local og_stop_secondary_music = stop_secondary_music
_G.stop_secondary_music = function(fadeTimer)
    secondaryTargetFadeTimer = (not secondaryTargetFadeOut) and secondaryTargetFadeTimer or 0
    secondaryTargetFadeTarget = fadeTimer or 0
    secondaryTargetFadeOut = false

    og_stop_secondary_music(fadeTimer)
end

musicTracks = {
    {
        name = "Main Theme",
        artist = "Super Mario 64",
        seq = SEQ_LEVEL_GRASS,
    },
    {
        name = "Slider",
        artist = "Super Mario 64",
        seq = SEQ_LEVEL_SLIDE,
    },
    {
        name = "Inside the Castle Walls",
        artist = "Super Mario 64",
        seq = SEQ_LEVEL_INSIDE_CASTLE,
    },
    {
        name = "Dire, Dire Docks",
        artist = "Super Mario 64",
        seq = SEQ_LEVEL_WATER,
    },
    {
        name = "Lethal Lava Land",
        artist = "Super Mario 64",
        seq = SEQ_LEVEL_HOT,
    },
    {
        name = "Snow Mountain",
        artist = "Super Mario 64",
        seq = SEQ_LEVEL_SNOW,
    },
    {
        name = "Haunted House",
        artist = "Super Mario 64",
        seq = SEQ_LEVEL_SPOOKY,
    },
    {
        name = "Cave Dungeon",
        artist = "Super Mario 64",
        seq = SEQ_LEVEL_UNDERGROUND,
    },
    {
        name = "Piranha Plant's Lullaby",
        artist = "Super Mario 64",
        seq = SEQ_EVENT_PIRANHA_PLANT,
    },
}

function get_music_data_from_name(stream)
    for id, data in pairs(musicTracks) do
        if stream == data.name then
            return id, data
        end
    end
end

function get_music_data_from_stream(stream)
    for id, data in pairs(musicTracks) do
        if stream == data.stream or stream == data.seq then
            return id, data
        end
    end
end

local function load_music_storage(modFs, loadPlaylists)
    if type(modFs) == "string" then
        local modFsGet = mod_fs_get(modFs)
        if modFsGet then
            modFs = modFsGet
        else
            log_to_console("[Squishy Radio] ModFs Folder '"..modFs.."' Not Found!", CONSOLE_MESSAGE_WARNING)
            return false
        end
    end
    if not modFs then
        log_to_console("[Squishy Radio] ModFs Folder does not exist!", CONSOLE_MESSAGE_WARNING)
        return false
    end
    local audioFiles = 0
    for i = 0, modFs.numFiles - 1 do
        local fileName = modFs:get_filename(i)
        local file = modFs:get_file(fileName)

        if string_endswith(fileName, ".ogg") or string_endswith(fileName, ".mp3") then
            audioFiles = audioFiles + 1
            local audio = audio_stream_load("modfs:/"..modFs.modPath.."/"..file.filepath)
            local fileBytes = file:read_bytes(file.size)
            if string_endswith(fileName, ".ogg") then
                local titleStart, titleEnd = string.find(string.lower(fileBytes), "title=([%w%s_,-]+)")
                local artistStart, artistEnd = string.find(string.lower(fileBytes), "artist=([%w%s_,-]+)")

                -- account for weird audacity splitter
                if math.abs(artistEnd - titleStart) < 5 then
                    artistEnd = artistEnd - 1
                end

                table.insert(musicTracks, {
                    name = titleStart and string.gsub(string.sub(fileBytes, titleStart + 6, titleEnd), "\n", "") or string.gsub(fileName, ".ogg", ""),
                    artist = artistStart and string.gsub(string.sub(fileBytes, artistStart + 7, artistEnd), "\n", "") or "???",
                    stream = audio,
                })
            else
                -- Lowkey idk how to read mp3 metadata ts too hard
                table.insert(musicTracks, {
                    name = string.gsub(fileName, ".mp3", ""),
                    artist = "???",
                    stream = audio,
                })
            end
        end
    end
    if audioFiles > 0 then
        log_to_console("[Squishy Radio] ModFs Folder '"..modFs.modPath.."' Loaded with "..audioFiles.." tracks!", CONSOLE_MESSAGE_INFO)
        return true
    else
        log_to_console("[Squishy Radio] ModFs Folder '"..modFs.modPath.."' does not have any audio!", CONSOLE_MESSAGE_WARNING)
        return false
    end
end

local modFs = mod_fs_get() or mod_fs_create() ---@type ModFs
modFs:set_public(true)
load_music_storage(modFs, true)
local dirFile = modFs:get_file("directories.txt") or modFs:create_file("directories.txt", true)
local dirsString = dirFile:read_string()
dirFile:erase(dirFile.size)
dirFile:set_text_mode(true) -- Set mode to text
dirFile:rewind() -- Reset offset to the beginning of the file
if dirsString then
    local dirs = string_split(dirsString, "|")
    local writeDirs = ""
    for _, dir in pairs(dirs) do
        local modFs = mod_fs_get(dir)
        if not modFs then
            log_to_console("[Squishy Radio] ModFs Folder '"..dir.."' Not Found!")
        else
            if load_music_storage(modFs) then
                
            else
                log_to_console("[Squishy Radio] ModFs Folder '"..dir.."' has no Audio!")
            end
            writeDirs = writeDirs .. modFs.modPath .. "|"
        end
    end
    dirFile:write_string(writeDirs)
end
modFs:save()

-- Assign Music to playlists
local seqPlaylist = {}

local seqPrefixes = {
    "SEQ_LEVEL_",
    "SEQ_MENU_",
    "SEQ_EVENT_",
}

for varName, seqId in pairs(_G) do
    for _, prefFind in pairs(seqPrefixes) do
        if string.find(varName, prefFind) then
            seqPlaylist[seqId] = {
                name = varName
            }
            local playlistFile = modFs:get_file(varName.."_playlist.txt")
            if playlistFile and playlistFile.size > 0 then
                local nameList = string_split(playlistFile:read_string(), "|")
                for i = 1, #nameList do
                    local _, data = get_music_data_from_name(nameList[i])
                    if data then
                        table.insert(seqPlaylist[seqId], data)
                    end
                end
            else
                local _, data = get_music_data_from_stream(seqId)
                if data then
                    table.insert(seqPlaylist[seqId], data)
                end
            end
        end
    end
end

currPlaylistPos = 1

local playerPopups = {}
local function player_popup(string, icon)
    table.insert(playerPopups, 1, {
        string = string,
        icon = icon,
        timer = 150,
    })
end

local looping = false
local prevPlaylistPos = 1
local streamPos = 0
local streamHangCounter = 0
local overridePauseVolume = 1
local overridePauseFrequency = 1
local playMusicInternal = false
local initMusic = true
local resetMusic = true
local function update()
    -- Song Change Stuffs
    if prevPlaylistPos ~= currPlaylistPos or resetMusic then
        initMusic = true
        local currData = musicTracks[currPlaylistPos]
        local prevData = musicTracks[prevPlaylistPos]

        if prevData.stream then
            audio_stream_stop(prevData.stream)
        end
            playMusicInternal = true
            set_background_music(SEQ_PLAYER_LEVEL, 0, 0)
            playMusicInternal = false
        player_popup("Now Playing: " .. currData.name .. " / " .. currData.artist, gTextures.mario_head)
        streamPos = 0
        prevPlaylistPos = currPlaylistPos
        resetMusic = false
    end

    local data = musicTracks[currPlaylistPos]

    -- Player Controls
    --[[
    if controller.buttonPressed & L_JPAD ~= 0 then
        player_popup("Previous Song")
        currPlaylistPos = num_wrap(currPlaylistPos - 1, 1, #musicTracks)
    end
    if controller.buttonPressed & R_JPAD ~= 0 then
        player_popup("Next Song")
        currPlaylistPos = num_wrap(currPlaylistPos + 1, 1, #musicTracks)
    end
    if controller.buttonPressed & D_JPAD ~= 0 then
        looping = not looping
        player_popup("Looping " .. (looping and "Single Track" or "All Tracks"))
    end
    ]]

    if not data then return end

    if data.stream then
        -- Update Track Single Looping
        audio_stream_set_looping(data.stream, looping)
        if looping then
            if data.loopA ~= nil and data.loopB ~= nil then
                audio_stream_set_loop_points(data.stream, data.stream.frequency * data.loopA, data.stream.frequency * data.loopB)
            end
        else
            audio_stream_set_loop_points(data.stream, 0, 0)
        end

        -- "Muffle" song when paused
        overridePauseVolume = math.lerp(overridePauseVolume, is_game_paused() and 0.25 or 1, 0.2)
        overridePauseFrequency = math.lerp(overridePauseFrequency, is_game_paused() and 0.75 or 1, 0.2)

        -- Secondary Music Functionality
        local volume = sequence_player_get_fade_volume(SEQ_PLAYER_LEVEL)
        secondaryTargetFadeTimer = approach_f32(secondaryTargetFadeTimer, secondaryTargetFadeTarget, 1, 1)

        --local fadeTimer = secondaryTargetFadeOut and (secondaryTargetFadeTarget - secondaryTargetFadeTimer) or secondaryTargetFadeTimer
        --local secondaryVolume = math.lerp(secondaryTargetVolume, 1, secondaryTargetFadeTarget ~= 0 and fadeTimer/secondaryTargetFadeTarget or 1)
        
        audio_stream_set_volume(data.stream, overridePauseVolume * volume)
        audio_stream_set_frequency(data.stream, overridePauseFrequency)

        if data.stream.loaded then
            if initMusic then
                playMusicInternal = true
                audio_stream_play(data.stream, false, 0)
                audio_stream_set_position(data.stream, streamPos)
                audio_stream_set_volume(data.stream, 1)
                playMusicInternal = false
                initMusic = false
            end

            if streamPos ~= audio_stream_get_position(data.stream) then
                streamPos = audio_stream_get_position(data.stream)
                streamHangCounter = 0
            else
                if streamHangCounter > 5 or (data.length and streamPos >= data.length and not looping) then
                    if not looping then
                        currPlaylistPos = num_wrap(currPlaylistPos + 1, 1, #musicTracks)
                    end
                    streamPos = 0
                    streamHangCounter = 0
                else
                    streamHangCounter = streamHangCounter + 1
                end
            end
        end
    else
        if initMusic then
            playMusicInternal = true
            set_background_music(SEQ_PLAYER_LEVEL, data.seq, 0)
            playMusicInternal = false
            initMusic = false
        end
    end
end

local hudStreamPos = 0
local scale = 0.3
local function hud_render()
    djui_hud_set_resolution(RESOLUTION_N64)
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    djui_hud_set_font(FONT_SPECIAL)

    -- Render Player
    local currData = musicTracks[currPlaylistPos]
    djui_hud_set_color(0, 0, 0, 255)
    djui_hud_render_rect(screenWidth - 80, screenHeight - 20, 80, 20)
    djui_hud_set_color(255, 255, 255, 150)
    djui_hud_render_rect(screenWidth - 80, screenHeight - 20, 80, 5)
    if currData then
        hudStreamPos = 0--math.lerp(hudStreamPos, (streamPos * 44100/currData.stream.frequency)/(currData.length or 0), 0.3)
    end
    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_render_rect(screenWidth - 80, screenHeight - 20, 80*hudStreamPos, 5)

    -- Render Popups
    for i = 1, #playerPopups do
        local popup = playerPopups[i]
        local text = popup.string
        local icon = popup.icon
        local width = djui_hud_measure_text(text)*0.3 + 10 + (icon and 16*scale + 3 or 0)
        local y = 30 + 16*i
        djui_hud_set_color(0, 0, 0, 150)
        djui_hud_render_rect(screenWidth - width, y, width + 2, 32*scale + 4)
        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_print_text(text, screenWidth - width + (icon and 16*scale + 3 or 0) + 5, y + 2, scale)
        if icon then
            djui_hud_render_texture(icon, screenWidth - width + 2, y + 2, (icon.width / 16) * scale * 2, (icon.height / 16) * scale * 2)
        end

        if popup.timer <= 0 then
            table.remove(playerPopups, i)
        end
        popup.timer = popup.timer - 1
    end
end

local function seq_load(player, seqId)
    if not playMusicInternal and player == SEQ_PLAYER_LEVEL then
        local randSong = nil
        local list = seqPlaylist[seqId]
        if list then
            currPlaylistPos = get_music_data_from_name(list[math.random(1, #list)].name)
        end
        resetMusic = true
        return 0
    end
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_HUD_RENDER, hud_render)
hook_event(HOOK_ON_SEQ_LOAD, seq_load)

local function chat_command(msg)
    local msgSplit = string_split(msg)
    if msgSplit[1] == "load" then
        local path = ""
        for i = 2, #msgSplit do
            path = path .. msgSplit[i] .. (i == #msgSplit and "" or " ")
        end
        path = string.gsub(path, ".modfs", "")
        if load_music_storage(path) then
            djui_chat_message_create("Added '"..path.."!'")
            dirFile:write_string(path.."|")
            modFs:save()
        else
            djui_chat_message_create("Failed to find ModFs file '"..path.."'")
        end
        return true
    end

    menuPage = 1
    return true
end

hook_chat_command("radio", "- blah blahh", chat_command)

-- Menu
menuPage = 0
currScroll = 1

local currSeqId = SEQ_LEVEL_GRASS
local function hud_render()
    if menuPage == 0 then return end
    local controller = gMarioStates[0].controller
    djui_hud_set_resolution(RESOLUTION_N64)
    if controller.buttonPressed & L_TRIG ~= 0 then
        --player_popup("Previous Song")
        currSeqId = num_wrap(currSeqId - 1, 1, #seqPlaylist)
    end
    if controller.buttonPressed & R_TRIG ~= 0 then
        --player_popup("Next Song")
        currSeqId = num_wrap(currSeqId + 1, 1, #seqPlaylist)
    end

    local listMax = #seqPlaylist[currSeqId] + 1
    if controller.buttonPressed & U_JPAD ~= 0 then
        --player_popup("Previous Song")
        currScroll = num_wrap(currScroll - 1, 1, listMax)
    end
    if controller.buttonPressed & D_JPAD ~= 0 then
        --player_popup("Next Song")
        currScroll = num_wrap(currScroll + 1, 1, listMax)
    end

    djui_hud_set_color(0, 0, 0, 200)
    djui_hud_render_rect(10, 10, 150, 200)
    djui_hud_set_font(FONT_NORMAL)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(seqPlaylist[currSeqId].name, 20, 15, 0.25, 0.25)

    local listLength = 0
    for i = 1, listMax - 1 do
        local currTrack = seqPlaylist[currSeqId][i]
        if currScroll == i then
            if controller.buttonPressed & L_JPAD ~= 0 then
                local currId = get_music_data_from_name(currTrack.name)
                --player_popup("Previous Song")
                seqPlaylist[currSeqId][i] = musicTracks[num_wrap(currId - 1, 1, #musicTracks)]
            end
            if controller.buttonPressed & R_JPAD ~= 0 then
                local currId = get_music_data_from_name(currTrack.name)
                --player_popup("Next Song")
                seqPlaylist[currSeqId][i] = musicTracks[num_wrap(currId + 1, 1, #musicTracks)]
            end
            if controller.buttonPressed & A_BUTTON ~= 0 then
                currPlaylistPos = get_music_data_from_name(currTrack.name)
            end
            if controller.buttonPressed & X_BUTTON ~= 0 then
                table.remove(seqPlaylist[currSeqId], i)
            end

            djui_hud_set_color(255, 255, 255, 255)
        else
            djui_hud_set_color(255, 255, 255, 150)
        end
        listLength = listLength + 20
        djui_hud_print_text(currTrack.name, 20, listLength, 0.5)
    end

    if currScroll == listMax then
        listLength = listLength + 20
        if controller.buttonPressed & A_BUTTON ~= 0 then
            table.insert(seqPlaylist[currSeqId], musicTracks[1])
        end
    end

    if controller.buttonPressed & B_BUTTON ~= 0 then
        menuPage = 0
        for _, playlist in pairs(seqPlaylist) do
            local playlistFile = modFs:get_file(playlist.name.."_playlist.txt") or modFs:create_file(playlist.name.."_playlist.txt", true)
            playlistFile:erase(dirFile.size)
            playlistFile:set_text_mode(true) -- Set mode to text
            playlistFile:rewind() -- Reset offset to the beginning of the file
            local listString = ""
            for i = 1, #playlist do
                listString = listString .. playlist[i].name .. "|"
            end
            playlistFile:write_string(listString)
        end
        modFs:save()
    end
end

hook_event(HOOK_ON_HUD_RENDER, hud_render)