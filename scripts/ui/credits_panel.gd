class_name CreditsPanel
extends UIPanel

const FILES := ["res://assets/models/CREDITS.md", "res://assets/CREDITS_media.md"]


func _init() -> void:
	super("Credite", 980.0)


func build() -> void:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = false
	rt.custom_minimum_size = Vector2(940, 560)
	rt.add_theme_font_size_override("normal_font_size", 17)
	var txt := "BUNKER: ZIUA ZERO\nUn joc făcut cu Godot Engine %s.\n\nFonturi: Oswald, Barlow, Share Tech Mono (SIL Open Font License).\n\n" % Engine.get_version_info().string
	for f in FILES:
		if FileAccess.file_exists(f):
			txt += FileAccess.get_file_as_string(f) + "\n\n"
	rt.text = txt
	body.add_child(rt)
