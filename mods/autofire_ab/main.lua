local autofire_state = { timer_A = 0, timer_B = 0, active_A = false, active_B = false }
local autofire_prev = {}

local SPEEDS = { 0.5, 0.4, 0.3, 0.2, 0.1, 0.05, 0.02, 0.01 }

local function snap_speed(rate, direction)
  local current_idx = 6
  for i, s in ipairs(SPEEDS) do
    if math.abs(rate - s) < 0.001 then
      current_idx = i
      break
    end
  end
  if direction == "up" and current_idx < #SPEEDS then
    return SPEEDS[current_idx + 1]
  elseif direction == "down" and current_idx > 1 then
    return SPEEDS[current_idx - 1]
  end
  return rate
end

return function(mod)
  mod.options:define({
    { key = "enabled", label = "AUTOFIRE TOGGLE", type = "toggle", default = true },
    { key = "rate", label = "AUTOFIRE RATE", type = "choice", default = 0.05, choices = {
      { "0.50s (Very Slow)", 0.5 },
      { "0.40s (Slower)", 0.4 },
      { "0.30s (Slow)", 0.3 },
      { "0.20s (Medium-Slow)", 0.2 },
      { "0.10s (Medium)", 0.1 },
      { "0.05s (Fast)", 0.05 },
      { "0.02s (Very Fast)", 0.02 },
      { "0.01s (Ultra)", 0.01 },
    } },
  })

  mod.hooks:wrap("core.update", function(next_fn, game, dt)
    local toggle_pressed = false
    if love.keyboard and love.keyboard.isDown then
      local down = love.keyboard.isDown("t")
      if down and not autofire_prev.t then toggle_pressed = true end
      autofire_prev.t = down
    end
    if love.joystick and love.joystick.getJoysticks then
      local pads = love.joystick.getJoysticks()
      if pads and pads[1] and pads[1].isGamepadDown then
        local down = pads[1]:isGamepadDown("back") or pads[1]:isGamepadDown("select")
        if down and not autofire_prev.pad_toggle then toggle_pressed = true end
        autofire_prev.pad_toggle = down
      end
    end
    if love.touch and love.touch.getTouches and love.touch.getPosition then
      local touch_down = false
      local touches = love.touch.getTouches()
      for _, id in ipairs(touches) do
        local tx, ty = love.touch.getPosition(id)
        if tx <= 300 and ty <= 300 then
          touch_down = true
          break
        end
      end
      if touch_down and not autofire_prev.touch_toggle then toggle_pressed = true end
      autofire_prev.touch_toggle = touch_down
    end

    if toggle_pressed then 
      mod.options.enabled = not mod.options.enabled 
    end

    local speed_inc, speed_dec = false, false
    if love.keyboard and love.keyboard.isDown then
      local p_down = love.keyboard.isDown("=") or love.keyboard.isDown("+") or love.keyboard.isDown("kp+")
      local m_down = love.keyboard.isDown("-") or love.keyboard.isDown("kp-")
      
      if p_down and not autofire_prev.plus then speed_inc = true end
      if m_down and not autofire_prev.minus then speed_dec = true end
      autofire_prev.plus = p_down
      autofire_prev.minus = m_down
    end
    
    if love.joystick and love.joystick.getJoysticks then
      local pads = love.joystick.getJoysticks()
      if pads and pads[1] and pads[1].isGamepadDown then
        local u_down = pads[1]:isGamepadDown("dpup")
        local d_down = pads[1]:isGamepadDown("dpdown")
        
        if u_down and not autofire_prev.pad_up then speed_inc = true end
        if d_down and not autofire_prev.pad_down then speed_dec = true end
        autofire_prev.pad_up = u_down
        autofire_prev.pad_down = d_down
      end
    end
    
    if speed_inc then mod.options.rate = snap_speed(mod.options.rate, "up") end
    if speed_dec then mod.options.rate = snap_speed(mod.options.rate, "down") end

    local Input = package.loaded["src.core.Input"]
    if Input then
      for _, btn in ipairs({"a", "b"}) do
        local timer_k = (btn == "a") and "timer_A" or "timer_B"
        local active_k = (btn == "a") and "active_A" or "active_B"
        
        local is_held = false
        if mod.options.enabled and Input.sources and Input.sources[btn] then
          for source, _ in pairs(Input.sources[btn]) do
            if source ~= "autofire" then
              is_held = true
              break
            end
          end
        end
        
        if is_held then
          autofire_state[timer_k] = autofire_state[timer_k] + dt
          if autofire_state[timer_k] >= mod.options.rate then
            autofire_state[timer_k] = 0
            autofire_state[active_k] = not autofire_state[active_k]
            
            Input.state[btn] = autofire_state[active_k]
            if autofire_state[active_k] then
              table.insert(Input.pressQueue, btn)
            end
          end
        else
          autofire_state[timer_k] = 0
          if autofire_state[active_k] then
            autofire_state[active_k] = false
            if not mod.options.enabled and Input.sources and Input.sources[btn] then
               local has_physical = false
               for src, _ in pairs(Input.sources[btn]) do
                 if src ~= "autofire" then has_physical = true break end
               end
               if has_physical then Input.state[btn] = true end
            end
          end
        end
      end
    end

    return next_fn(game, dt)
  end)

  mod.hooks:wrap("render.hud", function(next_fn, game, viewport)
    next_fn(game, viewport)

    love.graphics.push("all")
    local status_str = string.format("Autofire: %s | Speed: %.2fs", mod.options.enabled and "ON" or "OFF", mod.options.rate)
    
    local font = love.graphics.getFont()
    local tw = font:getWidth(status_str)
    local th = font:getHeight()
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 5, 55, tw + 10, th + 10)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(status_str, 10, 60)
    
    love.graphics.pop()
  end)
end
