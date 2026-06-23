------ SYSTEM ------
-- Setup (element 16 = system)
N = self:element_index() - 1
R = 0
G = 100
B = 200
Sen_avg = 100
Vel_avg = 50
Sen_hi = 150
Vel_hi = 150
Sen_lo = 100
Vel_lo = 0
BanksCC = {}
BanksCh = {}
BanksVal = {}
CurBank = 1
Shifted = false
Ready = false
EncMinCC_1 = 16
EncMaxCC_1 = 31
EncMinCC_2 = 71
EncMaxCC_2 = 118
clrBaseCC = 33
self.rgb = { -1, -1, -1, -1, -1, -1 }
self.step = 0
function now(n)
  timer_start(n, 1)
end
self.midirx_cb = function(self, hdr, evt)
  local ch, cmd, cc, v = evt[1], evt[2], evt[3], evt[4]
  local idx = cc - (cc > EncMaxCC_1 and (EncMinCC_2 - EncMaxCC_1 - 1) or 0) - EncMinCC_1
  local n = idx % (N + 1)
  if hdr[1] ~= 13 or ch ~= 0 or cmd ~= 176 or v == nil then
    return
  end
  if cc >= clrBaseCC and cc <= (clrBaseCC + 5) then
    self.rgb[cc - clrBaseCC + 1] = v
    self.sync_color()
  elseif idx >= 0 and idx <= EncMaxCC_2 then
    BanksVal[ch + 1][n + 1] = v
    if BanksCh[CurBank][n + 1] == ch then
      element[n]:encoder_value(v)
      if not element[n]:animated() then
        led_value(n, 2, v * 2)
      end
    end
  end
end
now(self:element_index())
for n = 0, N do
  element[n]:ini()
end


-- Timer (element 16 = system)
function pack_8b(h, l)
    return (h << 4) | l
end
self.sync_color = function()
    local c = self.rgb
    for i = 1, 6 do
        if c[i] < 0 then
            return
        end
    end
    R = pack_8b(c[1], c[2])
    G = pack_8b(c[3], c[4])
    B = pack_8b(c[5], c[6])
    immediate_send(nil, nil, 'r_color_track(' .. R .. ',' .. G .. ',' .. B .. ')')
    for i = 1, 6 do
        self.rgb[i] = -1
    end
end
self.anim_boot = function(ns, r, g, b, f)
    for i = 1, #ns do
        led_color(ns[i], 2, r, g, b, 0)
        led_animation_phase_rate_type(ns[i], 2, 0, f, 0)
    end
end
local f = self.anim_boot
local s = self.step
local n = self:element_index()
if s == 0 then
    f({15}, 0xdb, 0, 0, 1)
    s = 1
    timer_start(n, 350)
elseif s == 1 then
    f({10, 11, 14}, 0, 0xdb, 0, 2)
    s = 2
    timer_start(n, 300)
elseif s == 2 then
    f({5, 6, 7, 9, 13}, 0, 0xdb, 0, 2)
    s = 3
    timer_start(n, 350)
elseif s == 3 then
    f({0, 1, 2, 3, 4, 8, 12}, 0, 0xdb, 0, 3)
    s = 4
    timer_start(n, 400)
elseif s == 4 then
    f({15}, 0xdb, 0, 0, 3)
    f({10, 11, 14}, 0, 0xdb, 0, 5)
    f({5, 6, 7, 9, 13}, 0, 0xdb, 0, 4)
    f({0, 1, 2, 3, 4, 8, 12}, 0, 0xdb, 0, 3)
    s = 5
    timer_start(n, 3000)
elseif s == 5 then
    stop_anim()
    for n = 0, N do
        led_color(n, 2, R, G, B, 0)
    end
    Ready = true
    s = -1
end
self.step = s



------ ELEMENT 15 ------
-- Setup (element 15)
function led_vb(n, v, b)
    led_color(n, 2, R, G, B, b)
    led_value(n, 2, v * 2)
end
function saw(e, f, t, i_min, i_max)
    local n = e:element_index()
    if i_max < i_min then
        i_max = i_min
    end
    local range = i_max - i_min
    local period = t / f
    local timer = math.max(30, math.min(math.floor(period / range), 60))
    local steps = period / timer
    local cur = e.saw_step / (steps > 1 and (steps - 1) or 1)
    local i = math.floor(i_min + (range * cur) + 0.5)
    if e.saw_state == 0 then
        e.saw_step = 0
        led_vb(n, i_max, 0)
    else
        if e.saw_step == 0 then
            led_vb(n, i, 1)
        else
            led_vb(n, i, 0)
            if e.saw_step >= steps then
                e.saw_step = -1
            end
        end
        e.saw_step = e.saw_step + 1
        timer_start(n, timer)
    end
end



------ ELEMENT 14 ------
-- Setup (element 14)
function r_color_track(r, g, b)
    for n = 0, N do
        led_color_max(n, 2, r, g, b)
        led_color(n, 2, r, g, b, 0)
    end
end
function stop_anim()
    for n = 0, N do
        led_animation_phase_rate_type(n, 2, 0, 0, 0)
        led_color(n, 2, 0, 0, 0, 0)
    end
end
function blink(e, f, t, i_min, i_max)
    local n = e:element_index()
    local steps = f * 2 + 1
    local timer = t / steps
    if e.blink_state > 0 and e.blink_step < steps then
        if e.blink_state == 1 then
            e.blink_state = 2
            led_vb(n, i_min, 1)
        else
            e.blink_state = 1
            led_vb(n, i_max, 0)
        end
        e.blink_step = e.blink_step + 1
        timer_start(n, timer)
    else
        e.blink_step = 0
        e.blink_state = 0
        led_vb(n, i_max, 0)
        now(n)
    end
end



------ ELEMENT 13 ------
-- Setup (element 13)
function cmp(lo, hi, n)
    if n >= hi then
        return hi
    elseif n <= lo then
        return lo
    else
        return n
    end
end
function ctrl(n, dir)
    if Ready then
        local b = CurBank
        local e = element[n]
        local v = cmp(0, 127, BanksVal[b][n + 1] + dir)
        midi_send(BanksCh[b][n + 1], 176, BanksCC[b][n + 1], v)
        e:encoder_value(v)
        BanksVal[b][n + 1] = v
        if e.saw_state == 0 then
            led_vb(n, v, 0)
        end
        if v == 0 or v == 127 then
            e.blink_state = 1
            now(n)
        end
    end
end
function shift_turn(n)
    local e = element[n]
    if Shifted then
        e:encoder_sensitivity(Sen_lo)
        e:encoder_velocity(Vel_lo)
    else
        e:encoder_sensitivity(Sen_avg)
        e:encoder_velocity(Vel_avg)
    end
end
function r_toggle_shift()
    Shifted = not Shifted
    for n = 0, N do
        shift_turn(n)
    end
end



------ ELEMENT 12 ------
-- Setup (element 12)
idx = 0
for i = 1, 4 do
  BanksCC[i] = {}
  BanksCh[i] = {}
  BanksVal[i] = {}
  for j = 1, N + 1 do
    BanksCC[i][j] = idx + (idx > (EncMaxCC_1 - EncMinCC_1) and (EncMinCC_2 - EncMaxCC_1 - 1) or 0) + EncMinCC_1
    BanksCh[i][j] = 0
    BanksVal[i][j] = 0
    idx = idx + 1
  end
end
function save_bank()
    for n = 0, N do
        BanksVal[CurBank][n + 1] = element[n]:encoder_value()
    end
end
function load_bank(n)
    CurBank = n + 1
    for n = 0, N do
        local v = BanksVal[CurBank][n + 1]
        element[n]:encoder_value(v)
        led_vb(n, v, 0)
    end
end
function r_change_bank_en(n)
    save_bank()
    load_bank(n)
end



------ ELEMENTS 0-15
-- Setup (elements 0-15)
self:button_mode(0)
self:button_min(0)
self:button_max(127)
self:encoder_mode(0)
self:encoder_velocity(50)
self:encoder_min(0)
self:encoder_max(127)
self:encoder_sensitivity(100)
self.blink_state = 0
self.blink_step = 0
self.saw_state = 0
self.saw_step = 0
function self.animated()
    return self.blink_state > 0 or self.saw_state > 0
end


-- Button (elements 0-15)
local n = self:element_index()
local v = self:encoder_value()
if Ready then
    if self:button_state() > 0 then
        self:encoder_sensitivity(Sen_hi)
        self:encoder_velocity(Vel_hi)
        self.saw_step = 0
        self.saw_state = 1
        now(n)
    else
        shift_turn(n)
        self.saw_state = 0
        led_vb(n, v, 0)
    end
end


---- Encoder (elements 0-15)
local n = self:element_index()
local dir = self:encoder_state() - 64
ctrl(n, dir)


---- Timer (elements 0-15)
if self.blink_state > 0 then
  blink(self, 1, 300, 0, self:encoder_value())
elseif self.saw_state > 0 then
  saw(self, 1, 500, 0, self:encoder_value())
end