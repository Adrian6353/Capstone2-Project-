# Audio Asset Guide

This file describes what each audio asset should sound like and suggestions for creating or finding them.

## Sound Effects (Assets/Audio/SFX/)

### tower_fire.ogg / tower_fire_alt.ogg
- **Description**: Sound of a tower shooting/attacking
- **Duration**: 0.3 - 0.8 seconds
- **Character**: Sharp, percussive sound effect
- **Suggestions**:
  - Bow/arrow shooting sound
  - Laser beam pew sound
  - Cannon fire pop
  - Click/snap sound
- **Pitch Variation**: Add -0.1 to +0.1 variation for variety

### enemy_hit.ogg
- **Description**: Sound when a projectile hits an enemy
- **Duration**: 0.2 - 0.5 seconds
- **Character**: Impact sound, slightly comedic or satisfying
- **Suggestions**:
  - Thud or whack sound
  - Short "plink" sound
  - Impact crash
  - Punch/kick sound
- **Pitch Variation**: Add -0.15 to +0.15 variation for variety

### enemy_death.ogg
- **Description**: Sound when an enemy is defeated
- **Duration**: 0.4 - 1.0 seconds
- **Character**: Satisfying, complete sound
- **Suggestions**:
  - "Poof" disappearing sound
  - Explosion effect (small)
  - Powerdown/game over style sound
  - Chime or bell sound

### explosion.ogg (Optional, not currently used)
- **Description**: Explosion sound effect
- **Duration**: 0.5 - 2.0 seconds
- **Character**: Big impact sound
- **Suggestions**: Use for special tower attacks when implemented

### coin_collect.ogg
- **Description**: Sound when player earns money
- **Duration**: 0.3 - 0.6 seconds
- **Character**: Positive, rewarding sound
- **Suggestions**:
  - Coin jingle sound
  - "Cha-ching" cash register
  - Sparkle/magic sound
  - Ascending musical note

### tower_place.ogg
- **Description**: Sound when player builds a tower
- **Duration**: 0.3 - 0.7 seconds
- **Character**: Positive confirmation sound
- **Suggestions**:
  - Building/construction sound
  - Quick whoosh sound
  - Placed/dropped sound effect
  - Confirm beep

### tower_sell.ogg
- **Description**: Sound when player sells a tower
- **Duration**: 0.2 - 0.5 seconds
- **Character**: Neutral, clean sound
- **Suggestions**:
  - Reverse of place sound
  - Coins returning sound
  - Undo/delete beep
  - Subtle whoosh

### wave_start.ogg
- **Description**: Sound when a new enemy wave begins
- **Duration**: 0.5 - 1.5 seconds
- **Character**: Attention-grabbing, warning sound
- **Suggestions**:
  - Warning alarm (not too loud)
  - Ascending tone
  - Horn or siren sound
  - Dramatic stab

### game_over.ogg
- **Description**: Sound when player loses
- **Duration**: 0.5 - 1.5 seconds
- **Character**: Sad, game-over sound
- **Suggestions**:
  - Descending notes
  - "Trombone" sad sound
  - Game over chime
  - Dramatic loss sound

### game_win.ogg
- **Description**: Sound when player completes the level
- **Duration**: 0.7 - 2.0 seconds
- **Character**: Celebratory, triumph sound
- **Suggestions**:
  - Victory jingle
  - Ascending triumphant notes
  - Level complete fanfare
  - Bells or chimes

## UI Sounds (Assets/Audio/UI/)

### button_click.ogg
- **Description**: Sound when player clicks a button
- **Duration**: 0.1 - 0.3 seconds
- **Character**: Crisp, immediate response
- **Suggestions**:
  - Click sound
  - Short beep
  - Punch/tap sound
  - Lock/click mechanism

### button_hover.ogg
- **Description**: Sound when mouse hovers over a button
- **Duration**: 0.1 - 0.2 seconds
- **Character**: Subtle, non-intrusive
- **Suggestions**:
  - Soft beep or ping
  - Subtle whoosh
  - Light chime
  - Short "ding" sound
- **Note**: Remember to not play this too frequently as it can be annoying

## Background Music (Assets/Audio/Music/)

### main_menu.ogg
- **Description**: Background music for the main menu
- **Duration**: 30 seconds - 2 minutes (will loop)
- **Character**: Calm, inviting menu music
- **Suggestions**:
  - Relaxing instrumental track
  - Upbeat but not intense
  - Loopable composition
  - Theme music for the game
- **Bit Rate**: 128-192 kbps (can be lower quality than gameplay)

### gameplay_loop.ogg
- **Description**: Background music during normal gameplay
- **Duration**: 30 seconds - 2 minutes (will loop)
- **Character**: Engaging but not distracting
- **Suggestions**:
  - Uptempo instrumental track
  - Tower defense theme
  - Loopable without abrupt cuts
  - Relaxing but present
- **Bit Rate**: 128-192 kbps

### boss_wave.ogg (Optional)
- **Description**: Background music for special/boss waves
- **Duration**: 30 seconds - 2 minutes (will loop)
- **Character**: More intense or dramatic than normal gameplay
- **Suggestions**:
  - Faster tempo
  - More instruments
  - Dramatic elements
  - Loopable composition
- **Note**: Currently not implemented, but can be used when player reaches final/difficult waves

## Audio File Specifications

### Recommended Settings
- **Format**: OGG Vorbis (.ogg)
- **Sample Rate**: 44100 Hz
- **Bit Depth**: 16-bit
- **Channels**: 
  - Mono for SFX (saves file size)
  - Stereo for Music
- **Quality**: 
  - SFX: 96-128 kbps
  - Music: 128-192 kbps

### File Size Guidelines
- SFX: 20-100 KB each
- UI Sounds: 10-30 KB each
- Music: 500 KB - 2 MB each

## Format Conversion

If you have audio in WAV or MP3 format, convert to OGG using:
- **Audacity**: Free open-source audio editor (File > Export As... > Ogg Vorbis)
- **FFmpeg**: Command line: `ffmpeg -i input.wav -q:a 5 output.ogg`
- **Online converters**: Search for "WAV to OGG converter"

## Testing Audio

After adding audio files:
1. Place files in correct folders
2. Open the game in Godot
3. Play scenes and test audio functionality
4. If sounds don't play, check console for warnings with file paths
5. Verify file names match exactly in AudioManager.gd

## Creating Audio Assets

### Free Resources
- **Freesound.org**: Download and remix sounds (free with attribution)
- **OpenGameArt.org**: Community game art and audio
- **BFXR**: Generate retro pixel art sounds
- **Audacity**: Edit and create your own sounds

### Audio Tools
- **Audacity**: Open source, full-featured audio editor
- **GarageBand**: Mac only, easy to use
- **FL Studio**: Premium option with many samples
- **FMOD Studio**: Professional game audio

### Music Tools
- **MuseScore**: Create music from notation
- **GarageBand**: Loop-based music creation
- **OpenTTD Music**: Game music in public domain
- **YouTube Audio Library**: Free music and effects

## Implementation Status

Currently implemented audio triggers:
- ✅ Tower shooting
- ✅ Enemy hit impacts
- ✅ Enemy death
- ✅ Tower placement
- ✅ Tower selling
- ✅ Money collection
- ✅ Wave starting
- ✅ Game over/win
- ✅ Button clicks/hover
- ✅ Main menu music
- ✅ Gameplay music

Future possibilities:
- [ ] Tower upgrade sounds
- [ ] Special effects for towers
- [ ] Enemy type-specific sounds
- [ ] Victory music after level complete
- [ ] Sound effects volume settings UI
- [ ] Music/SFX toggle options
