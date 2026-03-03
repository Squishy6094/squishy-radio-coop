-- name: Squishy Music Player
-- description: A Music Player built into CoopDX

--- @class MusicPlayerData
--- @field public name string Song Name
--- @field public artist string Song Artist
--- @field public stream ModAudio 
--- @field public sampleRate integer The sample rate of your music (Reccomended to keep at 16000 or lower)
--- @field public loopA integer Where your music starts looping in seconds
--- @field public loopB integer Where your music stops looping in seconds
--- @field public length integer The duration of the song in seconds
--- @field public bpm integer Where your music stops looping

function num_wrap(num, min, max)
    return min + (num - min) % ((max + 1) - min)
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
        name = "Factory Investigation Remix",
        artist = "iR2-X (Newgrounds)",
        stream = audio_stream_load("factory-remix.ogg"),
        sampleRate = 16000,
        loopA = 24.143,
        loopB = 91.906,
        length = 91.906,
        bpm = 85,
    },
}

currPlaylistPos = 1

local playerPopups = {}
local function player_popup(string, icon)
    table.insert(playerPopups, 1, {
        string = string,
        icon = icon,
        timer = 150,
    })
end

local playing = false
local prevPlaying = false
local looping = false
local prevPlaylistPos = 1
local streamPos = 0
local streamHangCounter = 0
local overridePauseVolume = 1
local overridePauseFrequency = 1
local function update()
    local controller = gMarioStates[0].controller

    -- Song Change Stuffs
    if prevPlaylistPos ~= currPlaylistPos then
        local currData = musicTracks[currPlaylistPos]
        local prevData = musicTracks[prevPlaylistPos]

        audio_stream_stop(prevData.stream)
        player_popup("Now Playing: " .. currData.name .. " / " .. currData.artist, gTextures.mario_head)
        streamPos = 0
        prevPlaying = not playing
        prevPlaylistPos = currPlaylistPos
    end

    local data = musicTracks[currPlaylistPos]

    -- Player Controls
    if controller.buttonPressed & L_TRIG ~= 0 then
        playing = not playing
        player_popup("Playback " .. (playing and "Resumed" or "Paused"))
    end
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

    -- Update Track Single Looping
    audio_stream_set_looping(data.stream, looping)
    if looping then
        if data.sampleRate ~= nil and data.loopA ~= nil and data.loopB ~= nil then
            audio_stream_set_loop_points(data.stream, data.sampleRate * data.loopA, data.sampleRate * data.loopB)
        end
    else
        audio_stream_set_loop_points(data.stream, 0, 0)
    end

    -- "Muffle" song when paused
    overridePauseVolume = math.lerp(overridePauseVolume, is_game_paused() and 0.25 or 1, 0.2)
    overridePauseFrequency = math.lerp(overridePauseFrequency, is_game_paused() and 0.75 or 1, 0.2)

    -- Secondary Music Functionality
    secondaryTargetFadeTimer = approach_f32(secondaryTargetFadeTimer, secondaryTargetFadeTarget, 1, 1)

    local fadeTimer = secondaryTargetFadeOut and (secondaryTargetFadeTarget - secondaryTargetFadeTimer) or secondaryTargetFadeTimer
    local secondaryVolume = math.lerp(secondaryTargetVolume, 1, secondaryTargetFadeTarget ~= 0 and fadeTimer/secondaryTargetFadeTarget or 1)
    
    audio_stream_set_volume(data.stream, overridePauseVolume * secondaryVolume)
    audio_stream_set_frequency(data.stream, overridePauseFrequency)

    if data.stream.loaded then
        if prevPlaying ~= playing then
            if playing then
                audio_stream_play(data.stream, false, 0)
                audio_stream_set_position(data.stream, streamPos)
                audio_stream_set_volume(data.stream, 1)
            else
                audio_stream_pause(data.stream)
            end
            prevPlaying = playing
        end

        if playing then
            -- Handle Song Ending
            og_play_secondary_music(0, 0, 0, 50)
            if streamPos ~= audio_stream_get_position(data.stream) then
                streamPos = audio_stream_get_position(data.stream)
                streamHangCounter = 0
            else
                if streamHangCounter > 5 or (streamPos >= data.length and not looping) then
                    if not looping then
                        currPlaylistPos = num_wrap(currPlaylistPos + 1, 1, #musicTracks)
                    else
                        prevPlaying = not playing
                    end
                    streamPos = 0
                    streamHangCounter = 0
                else
                    streamHangCounter = streamHangCounter + 1
                end
            end
        else
            og_stop_secondary_music(50)
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
    hudStreamPos = math.lerp(hudStreamPos, (streamPos * 44100/currData.sampleRate)/currData.length, 0.3)
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

local function level_init()
    prevPlaying = not playing
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_HUD_RENDER, hud_render)
hook_event(HOOK_ON_LEVEL_INIT, level_init)

-- API --

---@param musicData MusicPlayerData Song Name
local function song_add(musicData)
    if musicData.stream == nil or not musicData.stream.isStream then
        log_to_console("[Squishy MP] Audio Stream Not Found", CONSOLE_MESSAGE_ERROR)
        return false
    end

    table.insert(musicTracks, {
        name = musicData.name,
        artist = musicData.artist,
        stream = musicData.stream,
        --fileName = musicData.stream.filepath:gsub("[/\\]+$", ""):gsub(".*[/\\]", ""),
        sampleRate = musicData.sampleRate,
        loopA = musicData.loopA,
        loopB = musicData.loopB,
        length = musicData.length,
        bpm = musicData.bpm,
    })
    return true
end

_G.squishMusic = {
    song_add = song_add,
}