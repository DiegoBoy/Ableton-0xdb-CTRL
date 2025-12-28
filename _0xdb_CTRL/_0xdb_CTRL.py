from _Framework.ControlSurface import ControlSurface
from _Framework.DeviceComponent import DeviceComponent
from _Framework.InputControlElement import MIDI_CC_TYPE
from _Framework.EncoderElement import EncoderElement
from _Framework.SubjectSlot import subject_slot
import Live

CC_STATUS_BYTE = 0xB0
CC_NUMBER_CTRL_BASE = 16
CC_NUMBER_R_HI = 110
CC_NUMBER_R_LO = 111
CC_NUMBER_G_HI = 112
CC_NUMBER_G_LO = 113
CC_NUMBER_B_HI = 114
CC_NUMBER_B_LO = 115
CC_NUMBER_B_lo = 115
SYSEX_START = 0xF0
SYSEX_END = 0xF7
SYSEX_MANUFACTURER_ID = 100
SYSEX_COMMAND = 0x01

class _0xdb_CTRL(ControlSurface):
    """
    Provides extended "blue hand" functionality:
        1. Up to 64 parameters are automatically mapped by Ableton where applicable
            a. Uses CCs 16-31 on channels 1-4
        2. When a new track is selected it sends its RGB using 2 types of MIDI messages:
            a. CC = [100..105], values mapped to [R_hi=100, R_lo, G_hi, G_lo, B_hi, B_lo=105]
            b. SYSEX = 0xdb, value = RGB
    """
    def __init__(self, c_instance):
        super(_0xdb_CTRL, self).__init__(c_instance)
        
        with self.component_guard():
            # 1. setup the 64-encoder hardware interface
            self._setup_encoders()
            
            # 2. setup the 'Blue Hand' device focus component
            self._device = DeviceComponent()
            self.set_device_component(self._device)
            
            # 3. setup listeners to follow your mouse/track selection
            self._on_appointed_device_changed.subject = self.song()
            self._on_selected_track_changed.subject = self.song().view
            
            # 4. initial assignment
            self._on_appointed_device_changed()


    def _setup_encoders(self):
        """ Creates 64 virtual encoders: 4 Channels (0-3) x 16 CCs (16-31) """
        self._encoders = []
        # channel loop (0-3 in Python = Channels 1-4 in MIDI)
        for channel in range(4):
            # cc loop (16-31 = General Purpose 1-4 + Undefined)
            for cc in range(16):
                encoder = EncoderElement(MIDI_CC_TYPE, channel, cc + CC_NUMBER_CTRL_BASE, Live.MidiMap.MapMode.absolute)
                self._encoders.append(encoder)


    @subject_slot('selected_track')
    def _on_selected_track_changed(self):
        """ Automatically focus the first device when you select a track """
        track = self.song().view.selected_track
        
        if not track:
            return
        
        if len(track.devices) > 0:
            self.song().appointed_device = track.devices[0]
        
        self._assign_parameters()
        
        color = track.color
        self._send_cc_color(color)
        self._send_sysex_color(color)


    @subject_slot('appointed_device')
    def _on_appointed_device_changed(self):
        """ Update the 'Blue Hand' and re-map encoders when the focused device changes """
        self._device.set_device(self.song().appointed_device)
        self._assign_parameters()


    def _assign_parameters(self):
        """ The engine that wires your 64 hardware encoders to the VST sliders """
        device = self.song().appointed_device
        if device:
            # clean current mappings
            for encoder in self._encoders:
                encoder.release_parameter()
            
            # get the plugin's exposed parameters (skipping the 'Device On' switch)
            all_params = device.parameters[1:] 
            
            # 1:1 direct wiring
            for i in range(64):
                if i < len(all_params):
                    self._encoders[i].connect_to(all_params[i])
            
            self.show_message(device.name + " (Ch 1-4, CC 16-31)")
        else:
            self.show_message("No device selected.")


    def _send_cc_color(self, color):
        """ Send RGB broken down into 6 CCs (R_hi, R_lo, G_hi, G_lo, B_hi, B_lo) """
        if not self._enabled:
            return
            
        r_8bit = (color >> 16) & 0xFF
        g_8bit = (color >> 8) & 0xFF
        b_8bit = color & 0xFF
        
        self._send_cc_color_hl(CC_NUMBER_R_LO, CC_NUMBER_R_HI, r_8bit)
        self._send_cc_color_hl(CC_NUMBER_G_LO, CC_NUMBER_G_HI, g_8bit)
        self._send_cc_color_hl(CC_NUMBER_B_LO, CC_NUMBER_B_HI, b_8bit)


    def _send_cc_color_hl(self, cc_number_lo, cc_number_hi, color_8bit):
        """ Send 8-bit color value broken down into 2 CCs (4 high bits + 4 low bits) """
        lo_4bit = color_8bit & 0x0F
        self._send_cc_color_4bit(cc_number_lo, lo_4bit)
        
        hi_4bit = color_8bit >> 4
        self._send_cc_color_4bit(cc_number_hi, hi_4bit)


    def _send_cc_color_4bit(self, cc_number, color_4bit):
        """ Send CC with 4-bit color value """
        if 0 <= color_4bit <= 127:
            self._send_midi((CC_STATUS_BYTE, cc_number, color_4bit))


    def _send_sysex_color(self, color):
        """ Send RGB using a SYSEX message """
        if not self._enabled:
            return

        sysex_message = [
            SYSEX_START,
            SYSEX_MANUFACTURER_ID,
            SYSEX_COMMAND,
        ]

        sysex_message.append(color & 0x7F) # bits 0-6 (LSB of B)
        sysex_message.append((color >> 7) & 0x7F) # bits 7-13 (MSB of B + LSB of G)
        sysex_message.append((color >> 14) & 0x7F) # bits 14-20 (MSB of G + LSB of R)
        sysex_message.append((color >> 21) & 0x7F) # bits 21-27 (MSB of R)
        sysex_message.append(SYSEX_END)
        
        self._send_midi(tuple(sysex_message))


    def disconnect(self):
        self._device = None
        super(_0xdb_CTRL, self).disconnect()