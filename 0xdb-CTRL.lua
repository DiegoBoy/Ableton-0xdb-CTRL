-------- EN16
------ Element 16 (System)
---- Setup
N = 15 -- number of buttons - 1
R = 0 -- default RGB
G = 100 -- default RGB
B = 200 -- default RGB
Sen_avg = 100 -- default sensitivity
Vel_avg = 50 -- default velocity
Sen_hi = 150 -- on-press sensitivity (Elektron-style)
Vel_hi = 150 -- on-press velocity (Elektron-style)
Sen_lo = 100 -- on-shift sensitivity (fine, granular control)
Vel_lo = 0 -- on-shift velocity (fine, granular control)
BanksCC = {} -- encoder CCs
BanksCh = {} -- encoder channels
BanksVal = {} -- encoder values
CurBank = 1 -- current bank number
Shifted = false -- is shift enabled?
Ready = false -- has init completed?

self.encBaseCC = 16 -- first CC of 16 sequential numbers assigned to encoders (14-31 is a block of unassigned CCs)
self.clrBaseCC = 110 -- first CC of 6 sequential numbers assigned to color (102-119 is a block of unassigned CCs)
self.rgb = {-1, -1, -1, -1, -1, -1} -- aux var to sync Ableton Live's color track (R_hi, R_lo, G_hi, G_lo, B_hi, B_lo)
self.step = 0 -- boot animation step

-- start timer event now
function now(n)
    timer_start(n, 1)
end

-- listens for MIDI messages to update encoder values and led colors based on active track
self.midirx_cb = function(self, evt, hdr)
    local ch, cmd, cc, v = evt[1], evt[2], evt[3], evt[4]
    local n = cc - self.encBaseCC
    if hdr[1] ~= 13 or ch < 0 or ch > 3 or cmd ~= 176 or v == nil or n < 0 then
        return
    end
    if cc >= self.clrBaseCC and cc <= (self.clrBaseCC + 5) then
        self.rgb[cc - self.clrBaseCC + 1] = v
        self.sync_color()
    elseif n <= N then
        BanksVal[ch + 1][n + 1] = v
        if BanksCh[CurBank][n + 1] == ch then -- is this message targeting the active bank?
            element[n]:encoder_value(v) -- update encoder value
            if not element[n]:animated() then -- update led value only when there's NO ongoing animation
                led_value(n, 2, v * 2)
            end
        end
    end
end

-- start System timer event
now(self:element_index())

-- initialize banks
for i = 1, 4 do
    BanksCC[i] = {}
    BanksCh[i] = {}
    BanksVal[i] = {}
    for j = 1, N + 1 do
        BanksCC[i][j] = self.encBaseCC + j - 1
        BanksCh[i][j] = i - 1
        BanksVal[i][j] = 0
    end
end

-- run Setup events of all encoders before their Button, Encoder or Timer events
-- this way we can make sure all necessary functions are defined when those events run
-- and we can bypass the char limit in System Setup
for n = 0, N do
    element[n]:ini()
end


---- Timer
-- restore original 8-bit color value from high and low bits
function pack_8b(h, l)
    return (h << 4) | l
end

-- waits for all hi and lo RGB bits, unpacks them and sends them to a remote call
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

-- animate leds in ns
self.anim_boot = function(ns, r, g, b, f)
    for i = 1, #ns do
        led_color(ns[i], 2, r, g, b, 0)
        led_animation_phase_rate_type(ns[i], 2, 0, f, 0)
    end
end

-- each step a different set of leds is animated
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
        led_color(n, 2, R, G, B, 0) -- set leds to default value
    end
    Ready = true
    s = -1
end
self.step = s


------ Element 15
---- Setup
-- set led's value and beautify settting
function led_vb(n, v, b)
    led_color(n, 2, R, G, B, b)
    led_value(n, 2, v * 2)
end

-- start a saw animation (increasing) where led intensity goes between i_min and i_max
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


------ Element 14
---- Setup
-- remote: on color track change update led colors
function r_color_track(r, g, b)
    for n = 0, N do
        led_color_max(n, 2, r, g, b)
        led_color(n, 2, r, g, b, 0)
    end
end

-- stops all leds
function stop_anim()
    for n = 0, N do
        led_animation_phase_rate_type(n, 2, 0, 0, 0)
        led_color(n, 2, 0, 0, 0, 0)
    end
end

-- makes a led blink with intensity between i_min and i_max
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


------ Element 13
---- Setup
-- ensure value of n is between lo and hi
function cmp(lo, hi, n)
    if n >= hi then
        return hi
    elseif n <= lo then
        return lo
    else
        return n
    end
end

-- function called when an encoder is turned
function ctrl(n, dir)
    if Ready then
        local b = CurBank
        local e = element[n]
        local v = cmp(0, 127, BanksVal[b][n + 1] + dir) -- make sure value is within valid range (0-127)
        midi_send(BanksCh[b][n + 1], 176, BanksCC[b][n + 1], v) -- send the value to the banks's channel / CC
        e:encoder_value(v) -- update encoder value
        BanksVal[b][n + 1] = v -- update bank value
        if e.saw_state == 0 then -- only update the led value if the saw animation is off
            led_vb(n, v, 0)
        end
        if v == 0 or v == 127 then -- make the led blink when the encoder goes past min or max (0 or 127)
            e.blink_state = 1
            now(n)
        end
    end
end

-- modifies sensitivity when shift is on 
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

-- remote: toggle shift on and off from BU16
function r_toggle_shift()
    Shifted = not Shifted
    for n = 0, N do
        shift_turn(n)
    end
end


------ Element 12
---- Setup
-- save all encoder values to the current bank
function save_bank()
    for n = 0, N do
        BanksVal[CurBank][n + 1] = element[n]:encoder_value()
    end
end

-- load values from bank into encoder values
function load_bank(n)
    CurBank = n + 1
    for n = 0, N do
        local v = BanksVal[CurBank][n + 1]
        element[n]:encoder_value(v)
        led_vb(n, v, 0)
    end
end

-- remote: use BU16 to switch active bank
function r_change_bank_en(n)
    save_bank()
    load_bank(n)
end


------ Elements 0-15 (all encoders)
---- Setup
-- button = momentary
self:button_mode(0)
self:button_min(0)
self:button_max(127)

-- encoder = absolute
self:encoder_mode(0)
self:encoder_velocity(50)
self:encoder_min(0)
self:encoder_max(127)
self:encoder_sensitivity(100)

-- init saw and blink animation variables
self.blink_state = 0
self.blink_step = 0
self.saw_state = 0
self.saw_step = 0

-- is an animation running on this led?
function self.animated()
    return self.blink_state > 0 or self.saw_state > 0
end


---- Button
local n = self:element_index()
local v = self:encoder_value()
if Ready then
    if self:button_state() > 0 then -- use high sensitivity when the pressed and turned (Elektron-style)
        self:encoder_sensitivity(Sen_hi)
        self:encoder_velocity(Vel_hi)
        self.saw_step = 0
        self.saw_state = 1
        now(n)
    else -- check if shift is pressed on BU16 and update led (if it is, use low, granular sensitivity)
        shift_turn(n)
        self.saw_state = 0
        led_vb(n, v, 0)
    end
end


---- Encoder
local n = self:element_index()
local dir = self:encoder_state() - 64 -- increment / decrement in value
ctrl(n, dir)


-------- BU16
------ Element 16 (System)
---- Setup
N = 15 -- number of buttons - 1
RgbDefault = {{0, 0x66, 0x33}, {0x22, 0x88, 0x88}, {0xAA, 0x66, 0}, {0x66, 0, 0xFF}} -- banks' default led colors
ButtonsBank = {} -- index of the elements that are part of the bank
BanksFun = {} -- functions to run on button events
BanksMode = {} -- button modes
BanksRgb = {} -- custom led colors
BanksState = {} -- button states
BanksVal = {} -- button values
CurBankBU = 1 -- BU16's current bank number
CurBankEN = 1 -- EN16's current bank number
Shifted = false -- is shift enabled?
Ready = false -- has init completed?

self.step = 0 -- boot animation step

-- remote: on change of Ableton Live's track, it receives the track's color 
function r_color_track(r, g, b)
end

-- NOP = no operation
function nop(n)
end

-- start system timer after 300ms to match EN16's slower boot
timer_start(self:element_index(), 300)

-- buttons 4-15 are part of the bank, except button 12 (shift)
for i = 4, 15 do
    if i ~= 12 then
        ButtonsBank[#ButtonsBank + 1] = i
    end
end

-- init banks with default values
for i = 1, 4 do
    BanksFun[i] = {}
    BanksMode[i] = {}
    BanksRgb[i] = {}
    BanksState[i] = {}
    BanksVal[i] = {}
    RgbDefault[i][4] = 1 -- we'll use 4-tuple colors (RGBA)
    for j = 1, N + 1 do
        BanksFun[i][j] = nop -- do nothing
        BanksMode[i][j] = 0 -- 0=momentary, 1=toggle, 2=2-step, 3=3-step
        BanksRgb[i][j] = RgbDefault[i]
        BanksState[i][j] = 0 -- button NOT pressed
        BanksVal[i][j] = 0
    end
end


---- Timer
-- animate the leds in ns
self.anim_boot = function(ns, r, g, b, f)
    for i = 1, #ns do
        led_color(ns[i], 1, r, g, b, 0)
        led_animation_phase_rate_type(ns[i], 1, 0, f, 0)
    end
end

-- stop all leds
self.stop_anim = function()
    for n = 0, N do
        led_animation_phase_rate_type(n, 1, 0, 0, 0)
        led_color(n, 1, 0, 0, 0, 0)
    end
end

-- boot animation: on each step a different set of leds is turned on, then Ready = true
local f = self.anim_boot
local s = self.step
local n = self:element_index()
if s == 0 then
    f({12}, 0xdb, 0, 0, 1)
    s = 1
    timer_start(n, 350)
elseif s == 1 then
    f({8, 9, 13}, 0, 0xdb, 0, 2)
    s = 2
    timer_start(n, 300)
elseif s == 2 then
    f({4, 5, 6, 10, 14}, 0, 0xdb, 0, 2)
    s = 3
    timer_start(n, 350)
elseif s == 3 then
    f({0, 1, 2, 3, 7, 11, 15}, 0, 0xdb, 0, 3)
    s = 4
    timer_start(n, 400)
elseif s == 4 then
    f({12}, 0xdb, 0, 0, 3)
    f({8, 9, 13}, 0, 0xdb, 0, 5)
    f({4, 5, 6, 10, 14}, 0, 0xdb, 0, 4)
    f({0, 1, 2, 3, 7, 11, 15}, 0, 0xdb, 0, 3)
    s = 5
    timer_start(n, 3000)
elseif s == 5 then
    self.stop_anim()
    load_bank(0) -- load the first BU16 bank + sets color of buttons that are part of bank
    r_change_bank_en(0) -- sets color of bank selection buttons Bank A,B,C,D
    element[12]:ini() -- call the shift button's Setup event
    s = -1
    Ready =  -- all modules should have finished initializing by now
end
self.step = s


------ Element 15 (sample bank button)
---- Setup
local i = self:element_index() + 1
BanksRgb[1][i] = {64, 52, 239, 1} -- set Bank A's color = blue
BanksMode[1][i] = 1 -- set Bank A's mode = toggle
BanksFun[1][i] = function(n) -- set Bank A's function = send CTRL+M
    keyboard_send(100, 1, 1, 1, 0, 2, 16, 1, 0, 1)
end


------ Element 12 (shift)
---- Setup
self.click_count = 0

-- call the remote shift toggle function on all modules
self.toggle = function()
    immediate_send(nil, nil, 'r_toggle_shift()')
end

-- remote: when shift is enabled it turns on its led and switches controls of Bank A,B,C,D from EN16 banks to BU16 banks
function r_toggle_shift()
    Shifted = not Shifted
    num_shift = 12
    if Shifted then
        color_bank_bu()
        led_value(num_shift, 1, 255)
    else
        color_bank_en()
        led_value(num_shift, 1, 0)
    end
end

-- button = momentary
self:button_mode(0)
self:button_min(0)
self:button_max(127)

-- led color = red
led_color(self:element_index(), 1, 0xdb, 0, 0, 0)
led_value(self:element_index(), 1, 0)


---- Button
-- single-click = momentary, double-click = toggle
if Ready then
    if self:button_state() > 0 then
        self.toggle()
        if self:button_elapsed_time() < 300 then
            self.click_count = self.click_count + 1
        else
            self.click_count = 1
        end
    else
        if self.click_count ~= 2 then
            self.toggle()
        end
    end
end


------ Element 1 (Bank B)
---- Setup
-- call function from bank when button is pressed
function ctrl_fun(n)
    if Ready then
        led_value(n, 1, element[n]:button_value() * 2)
        BanksFun[CurBankBU][n + 1](n)
    end
end

-- set color and animation of BU16 bank buttons (Bank A,B,C,D)
function color_bank_bu()
    for n = 0, 3 do
        local rgba = RgbDefault[n + 1]
        element[n]:led_color(1, {rgba})
        led_animation_phase_rate_type(n, 1, 0, 0, 0)
    end
    led_animation_phase_rate_type(CurBankBU - 1, 1, 0, 2, 1)
end

-- set color and animation of EN16 bank buttons (Bank A,B,C,D)
function color_bank_en()
    for n = 0, 3 do
        led_color(n, 1, 0xdb, 0xdb, 0xdb, 0)
        led_animation_phase_rate_type(n, 1, 0, 0, 0)
    end
    led_animation_phase_rate_type(CurBankEN - 1, 1, 0, 2, 1)
end


------ Element 0 (Bank A)
---- Setup
-- call remote function to switch EN16 bank (BU16 bank when shift = on)
function ctrl_bank(n)
    if Ready then
        if Shifted then
            change_bank_bu(n)
        else
            immediate_send(nil, nil, 'r_change_bank_en(' .. n .. ')')
        end
    end
end

-- switch BU16 bank
function change_bank_bu(n)
    save_bank()
    load_bank(n)
    color_bank_bu()
end

-- remote: when EN16 bank changes, update Bank A,B,C,D leds
function r_change_bank_en(n)
    CurBankEN = n + 1
    color_bank_en()

end

-- save button data to bank
function save_bank()
    for _, n in ipairs(ButtonsBank) do
        local i = n + 1
        local e = element[n]
        local m = e:button_mode()
        BanksMode[CurBankBU][i] = m
        BanksState[CurBankBU][i] = e:button_state()
        if m > 0 then
            BanksVal[CurBankBU][i] = e:button_value()
        end
    end
end

-- load data from bank into button
function load_bank(n)
    CurBankBU = n + 1
    for _, n in ipairs(ButtonsBank) do
        local i = n + 1
        local m = BanksMode[CurBankBU][i]
        local s = BanksState[CurBankBU][i]
        local v = BanksVal[CurBankBU][i]
        local rgba = BanksRgb[CurBankBU][i]
        local e = element[n]
        e:button_mode(m)
        e:button_state(s)
        e:button_value(v)
        e:led_color(1, {rgba})
        led_value(n, 1, v * 2)
    end
end


------ Elements 4-11, 13-15 (bank buttons)
---- Button
local n = self:element_index()
ctrl_fun(n)