#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Vivaldi Profile Work
# @raycast.mode silent
# @raycast.packageName Vivaldi

# Optional parameters:
# @raycast.icon /Users/mukit/.config/icons/vivaldi.icns
# @raycast.packageName Vivaldi Profile Work

# Documentation:
# @raycast.description Vivaldi Profile Work
# @raycast.author mimukit
# @raycast.authorURL https://raycast.com/mimukit



-- This block targets the Vivaldi application
tell application "Vivaldi"
	-- This command brings Vivaldi to the front, launching it if it's not already running.
	activate
end tell

-- A brief pause to ensure the application has time to become fully active
delay 0.5

-- This block tells "System Events" (the part of macOS that handles UI interactions) to perform actions
tell application "System Events"
	-- Simulate pressing the 'p' key while holding down the Shift and Command keys
	keystroke "p" using {shift down, command down}
	
	-- A brief pause to allow the UI to update after the shortcut
	delay 0.3
	
	-- Simulate pressing the Tab key. 48 is the key code for Tab.
	key code 48
	key code 48
	key code 48
	
	-- A brief pause
	delay 0.2
	
	-- Simulate pressing the Enter key. 36 is the key code for Enter.
	key code 36
end tell

