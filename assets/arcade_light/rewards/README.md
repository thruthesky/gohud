# arcade_light / rewards

Painted art for the quest and reward rows. Icons are full colour, about 160 px on the long side, transparent.

- `coin.png` 158x160 - shiny gold coin with a raised crown (currency, every row)
- `gift.png` 157x160 - red gift box with a gold ribbon (header)
- `quest_play.png` 160x107 - blue game controller (play matches)
- `quest_medal.png` 137x160 - gold medal with a star on a red ribbon (top 3)
- `quest_magnet.png` 160x158 - red and silver horseshoe magnet (repulses)
- `quest_powerup.png` 160x157 - glowing blue lightning power-up orb (pickups)
- `quest_star.png` 160x151 - shiny gold star (campaign wins)
- `quest_flame.png` 153x160 - red-orange flame badge (HARD stages cleared)
- `menu_daily.png` 192x192 - calendar with a green check and a sparkle (a main menu's daily-quests `GoSideButton`)
- `menu_achievements.png` 170x192 - gold trophy with a red star rosette on a navy base (a main menu's achievements `GoSideButton`)
- Both menu pictures are die-cut stickers: the art's silhouette, closed (handles, sparkles and body bridged) and hole-filled, grown by a white band of 10.5 px and a navy line of 3 px (at 192 px), antialiased at source size then downscaled. Baked from the 1024 px astra sources (distance transform, premultiplied LANCZOS downscale); the band is part of the picture, no shader draws it.
- Trophy, skull, clock and check are reused from `../leaderboard/` (`icon_trophy.png`, `icon_skull.png`, `icon_clock.png`, `check_green.png`).
- `row_cyan.png` 480x136 - empty pale glossy cyan row plate, thin bright cyan rim (open quest); nine-patch 96/96/56/56
- `row_gold.png` 480x136 - empty glossy gold row plate, gold rim (claimable quest); nine-patch 96/96/56/56
- `row_done.png` 480x136 - empty desaturated pale grey-blue row plate (finished quest); nine-patch 96/96/56/56
- `bar_track.png` 240x44 - empty dark navy progress track with rim; nine-patch 28/28/0/0 (stretch horizontally only)
- `bar_blue.png` 240x44 - glossy blue progress fill, same outline and size as the track; nine-patch 28/28/0/0
- `bar_green.png` 240x44 - glossy green progress fill (complete), same outline and size as the track; nine-patch 28/28/0/0
- `value_pill.png` 240x76 - empty pale cyan rimmed chip behind the coin balance and "resets in" text; nine-patch 44/44/0/0 (stretch horizontally only)
- `coin_heap.png` 320x310 - a heap of seven gold crown coins, the same coin as `coin.png` (`GoRewardBurst` from `heap_from` coins on); generated with OpenAI image generation from `coin.png` and `gift.png` as style references, trimmed and fitted to 320 px by `tools/paint_arcade_reward_fx.gd`
- `fx_rays.png` 512x512 - 16 soft warm-white wedges fading out to the rim; drawn additively and turned (`GoRewardBurst`'s long ray layer)
- `fx_rays_thin.png` 512x512 - 10 narrower, brighter wedges (the short layer turning the other way)
- `fx_glow.png` 256x256 - a round warm glow, white at the heart
- `fx_ring.png` 256x256 - a thin bright ring with a gold fringe (the burst's shockwave)
- `fx_sparkle.png` 64x64 - a four-point twinkle (the trail, the burst and the twinkles)
- `fx_glint.png` 128x128 - a crisp four-point star with long thin arms (the glint on the coin's rim)
- The six `fx_*` pieces are painted by `tools/paint_arcade_reward_fx.gd` (warm white #fff1b8 to gold #ffd75a, alpha the light's strength) and drawn with an additive blend over the burst's navy dim.
