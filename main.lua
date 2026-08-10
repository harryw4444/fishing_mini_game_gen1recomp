return function(mod)
  mod.log:info("fishing_minigame: entry chunk running")

  local Sound = require("src.core.Sound")
  local Game = require("src.core.Game")
  local PaletteFX = require("src.render.PaletteFX")

    local RODS = { OLD_ROD = true, GOOD_ROD = true, SUPER_ROD = true }

  -- Options
  mod.options:define({
    {
      key = "advanced_colours",
      type = "toggle",
      label = "Advanced colours",
      default = true,
    },
  })

  local function advancedColours()
    return mod.options:get("advanced_colours")
  end

  -- Sprites
  local fishImg = mod.assets:image("fish.png")
  local frameImg = mod.assets:image("frame.png")
  local rodImg = mod.assets:image("rod.png")
  local FISH_W, FISH_H = fishImg:getWidth(), fishImg:getHeight()
  local FRAME_W, FRAME_H = frameImg:getWidth(), frameImg:getHeight()
  local ROD_W, ROD_H = rodImg:getWidth(), rodImg:getHeight()


  -- Custom panel layout

  local PANEL = { x = 8, y = 90, w = 144, h = 48 }
  local FRAME_X = 20
  local FRAME_Y = PANEL.y + PANEL.h - FRAME_H - 6
  local ROD_X = FRAME_X
  local ROD_Y = FRAME_Y - ROD_H
  local TRACK_INSET_X, TRACK_INSET_Y = 4, 3

  -- Minigame state

  local minigame = {
    bar_x = FRAME_X + TRACK_INSET_X,
    bar_y = FRAME_Y + TRACK_INSET_Y,
    bar_w = FRAME_W - TRACK_INSET_X * 2,
    bar_h = FRAME_H - TRACK_INSET_Y * 2,
    cursor_x = 0,
    cursor_dir = 1,
    base_speed = 90,
    cursor_speed = 90,
    target_x = 30,
    target_w = 22,
    fish_count = 0,
    max_fish = 3,
  }

  local LINE_Y = minigame.bar_y + minigame.bar_h / 2

  local function randomizeTarget()
    local margin = 4
    local max_x = minigame.bar_w - minigame.target_w - margin
    minigame.target_x = math.random(margin, math.max(margin, max_x))
  end

  local function resetMinigame()
    minigame.fish_count = 0
    minigame.cursor_x = 0
    minigame.cursor_dir = 1
    minigame.cursor_speed = minigame.base_speed
    randomizeTarget()
  end

  mod.content.screens:register("FishingMinigame", {
    new = function(game, opts)
      mod.log:info("fishing_minigame: screen constructed")
      resetMinigame()
      opts = opts or {}
      local self = { game = game, isOpaque = false, done = false }

      local function finish(success)
        if self.done then return end
        self.done = true
        mod.log:info("fishing_minigame: finished, success=%s", tostring(success))
        game.stack:pop()
        if opts.onDone then opts.onDone(success) end
      end

      function self:update(dt)
        minigame.cursor_x = minigame.cursor_x + (minigame.cursor_dir * minigame.cursor_speed * dt)
        if minigame.cursor_x >= minigame.bar_w then
          minigame.cursor_x = minigame.bar_w
          minigame.cursor_dir = -1
        elseif minigame.cursor_x <= 0 then
          minigame.cursor_x = 0
          minigame.cursor_dir = 1
        end

        if game.input:wasPressed("a") then
          local hit = minigame.cursor_x >= minigame.target_x
            and minigame.cursor_x <= (minigame.target_x + minigame.target_w)

          if hit then
            Sound.play(game.data, "Tink")
            minigame.fish_count = minigame.fish_count + 1
            minigame.cursor_speed = minigame.cursor_speed + 25
            if minigame.fish_count >= minigame.max_fish then
              finish(true)
            else
              randomizeTarget()
            end
          else
            Sound.play(game.data, "Denied")
            minigame.fish_count = 0
            minigame.cursor_speed = minigame.base_speed
            randomizeTarget()
          end
        elseif game.input:wasPressed("b") then
          Sound.play(game.data, "Press_AB")
          finish(false)
        end
      end

      function self:draw()
        love.graphics.setColor(0.95, 0.95, 0.85, 0.95)
        love.graphics.rectangle("fill", PANEL.x, PANEL.y, PANEL.w, PANEL.h, 3, 3)
        love.graphics.setColor(0.06, 0.22, 0.06)
        love.graphics.rectangle("line", PANEL.x, PANEL.y, PANEL.w, PANEL.h, 3, 3)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(rodImg, ROD_X, ROD_Y)
        love.graphics.draw(frameImg, FRAME_X, FRAME_Y)
        local target_fish_x = minigame.bar_x + minigame.target_x
          + math.floor((minigame.target_w - FISH_W) / 2)
        local target_fish_y = minigame.bar_y
          + math.floor((minigame.bar_h - FISH_H) / 2)
        local frame_anchor_x = FRAME_X + FRAME_W - 1
        local frame_anchor_y = FRAME_Y + FRAME_H / 2
        if advancedColours() then
          love.graphics.setColor(0.3, 0.3, 0.3)
        else
          love.graphics.setColor(0, 0, 0)
        end
        love.graphics.setLineWidth(1)
        love.graphics.line(target_fish_x + FISH_W, LINE_Y, frame_anchor_x, frame_anchor_y)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(fishImg, target_fish_x, target_fish_y)

        if advancedColours() then
          love.graphics.setColor(1, 0, 0)
        else
          love.graphics.setColor(0, 0, 0)
        end
        love.graphics.setLineWidth(2)
        love.graphics.line(
          minigame.bar_x + minigame.cursor_x, minigame.bar_y - 2,
          minigame.bar_x + minigame.cursor_x, minigame.bar_y + minigame.bar_h + 2
        )
        love.graphics.setLineWidth(1)
      end
      function self:sgbPalettes(g)
        local zones = {}
        if g.overworld and g.overworld.sgbPalettes then
          local base = g.overworld:sgbPalettes() or {}
          for _, z in ipairs(base) do zones[#zones + 1] = z end
        end

        local tx1 = math.floor(PANEL.x / 8)
        local ty1 = math.floor(PANEL.y / 8)
        local tx2 = math.ceil((PANEL.x + PANEL.w) / 8) - 1
        local ty2 = math.ceil((PANEL.y + PANEL.h) / 8) - 1

        if advancedColours() then
          zones[#zones + 1] = PaletteFX.trueColorZone(tx1, ty1, tx2, ty2)
        else
          local colors = PaletteFX.pal(g.data, "MEWMON")
          if colors then
            zones[#zones + 1] = PaletteFX.zone(colors, tx1, ty1, tx2, ty2)
          end
        end

        return zones
      end

      return self
    end,
  })
  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, pool)
    if not RODS[rod] then
      return next(rod, mapId, pool)
    end
    if pool and #pool > 0 then
      local slot = pool[love.math.random(1, #pool)]
      return { species = slot.species, level = slot.level }
    end
    -- no pool for this map/rod (e.g. Old Rod's "always" case is already
    -- guaranteed by vanilla) -- fall through unchanged
    return next(rod, mapId, pool)
  end)
  local OverworldState = require("src.world.OverworldController")
  local vanillaGoFishing = OverworldState.goFishing
  mod.log:info("fishing_minigame: patching OverworldState.goFishing (was %s)", tostring(vanillaGoFishing))

  OverworldState.goFishing = function(self, rod)
    mod.log:info("fishing_minigame: goFishing called with rod=%s", tostring(rod))
    if not RODS[rod] then
      return vanillaGoFishing(self, rod)
    end

    mod.log:info("fishing_minigame: pushing minigame screen")
    local ok, err = pcall(mod.ui.push, Game, "FishingMinigame", {
      onDone = function(success)
        mod.log:info("fishing_minigame: onDone success=%s", tostring(success))
        if success then
          vanillaGoFishing(self, rod)
        end
      end,
    })
    if not ok then
      -- surfaces the real Lua error directly on screen -- no console needed
      mod.log:error("fishing_minigame: push failed: %s", tostring(err))
      Game.stack:push(mod.ui.TextBox.new(Game, "MOD ERROR: " .. tostring(err)))
    end
  end

  mod.log:info("fishing_minigame: patch installed (now %s)", tostring(OverworldState.goFishing))
end
