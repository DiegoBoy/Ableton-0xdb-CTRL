# About
Control Ableton Live with Intech EN16 + BU16. Map up to 64 paramaters, sync EN16 with track colors and more using these Ableton Control Surface (a.k.a. Remote Script) and Intech Cloud Profiles.

# Features
## EN16
- Banks = 4x16
  - Maps all 64 virtual encoders using Ableton "blue hand" (usually limited to 16)
- Encoder leds:
  - Sync color with active Ableton Live track
  - Blink when turned past min/max (0 and 127)
  - Saw animation while pressed
  - Animations reflect encoder value ("0 to current value" instead of "0 to max")
- Encoder velocity:
  - Default = avg
  - On shift = low (granular control)
  - On press = high (Elektron-style)
- Stand-alone, can be used without BU16:
  - Limited to first bank (default 16 encoders)
  - No shift

## BU16
- Banks = 4x11
  - Custom button color and function per bank
- Shift button (toggles on double-click)
- First 4 buttons control banks:
  - Default = EN16 banks
  - On shift = BU16 banks
  - Led animation for active bank

# Installation
## Intech Cloud Profiles
1. Load **EN16** profile using Grid Studio: `grid-editor://?config-link=b311Gnb8EWPdcKSy0MNs`
2. Load **BU16** profile using Grid Studio: `grid-editor://?config-link=37npWZoikG9kgPuebzdL`

## Ableton Control Surface
1. Close Ableton Live
2. Copy dir *_0xdb_CTRL* to the *Remote Scripts* dir in your Ableton's User Library:
* macOS = `/Users/[username]/Music/Ableton/User Library/Remote Scripts/`
* Windows = `C:\Users\[username]\Documents\Ableton\User Library\Remote Scripts\`
3. Select the *0xdb CTRL* Control Surface in Ableton Live:
  * `Settings > Link, Tempo & MIDI > MIDI`
    * Make sure that *Remote* is enabled for your device's `Output Ports`
4. Vibe with track colors and up to 64 params in sync.

# F.A.Q.
## Remote Script? Control Surface?
tl;dr - they are what external devices use to interact with Ableton Live.
 
Control Surfaces typically enable tactile control of Live, but they work both ways and they can also send updates to an external device. The Remote Script is the code that contains the Control Surface implementation.

## What version of Ableton Live is supported?
Ableton Live 11 and 12. Previous versions use Python 2.x and are incompatible with this Remote Script.

## Can I use this Control Surface instead of Intech's official "blue hand" script?
Yes, this Remote Script provides a superset of the functionality available via the Intech Studio script.

## Can I assign more than one Control Surface to the same device?
Yes, if your device already has a different Control Surface assigned, you can still add a second one to it - it will send in and receive MIDI out from all Control Surfaces assigned.

## How is track color kept in sync?
Color is sent in two formats:
* MIDI CC:
  * each byte of the RGB value (R_hi, R_lo, G_hi, G_lo, B_hi, B_lo) is sent using a different CC (110-115) on channels 1-4 (status byte = 0xB0). *
* SYSEX:
  * the whole RGB is sent with a single SYSEX message using manufacturer ID = 100 (no particular reason other than being in the valid range < 128). 

\* These CCs (110-115) are undefined by MIDI and shouldn't interfere with messages from other devices.
