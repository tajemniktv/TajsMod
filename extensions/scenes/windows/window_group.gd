extends "res://scenes/windows/window_group.gd"

# Expanded color palette
# Original: ["1a202c", "1a2b22", "1a292b", "1a1b2b", "211a2b", "2b1a27", "2b1a1a"]
const NEW_COLORS: Array[String] = [
	"1a202c", # #1a202c
	"1a2b22", # #1a2b22
	"1a292b", # #1a292b
	"1a1b2b", # #1A1B2B
	"211a2b", # #211a2b
	"2b1a27", # #2b1a27
	"2b1a1a", # #2b1a1a
	
	# New Additions
	"BE4242", # #BE4242
	"FFA500", # #FFA500
	"FFFF00", # #FFFF00
	"00FF00", # #00FF00
	"00FFFF", # #00FFFF
	"0000FF", # #0000FF
	"800080", # #800080
	"FF00FF", # #FF00FF
	"252525", # #808080
	"000000" # #000000
]

func update_color() -> void:
	# Override to use NEW_COLORS
	$TitlePanel.self_modulate = Color(NEW_COLORS[color])
	$PanelContainer.self_modulate = Color(NEW_COLORS[color])

func cycle_color() -> void:
	# Override to support larger size
	color += 1
	if color >= NEW_COLORS.size():
		color = 0
	update_color()
	
	color_changed.emit()
