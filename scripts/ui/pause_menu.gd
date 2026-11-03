class_name PauseMenu
extends UIPanel


func _init() -> void:
	super("Pauză", 520.0)


func build() -> void:
	body.add_theme_constant_override("separation", 10)
	body.add_child(UITheme.button("Continuă", close))
	var save_btn := UITheme.button("Salvează jocul", func() -> void:
		if State.save_game():
			State.notify.emit("Joc salvat.", "good")
		close())
	save_btn.disabled = State.context != "bunker"
	if save_btn.disabled:
		save_btn.tooltip_text = "Poți salva doar în buncăr."
	body.add_child(save_btn)
	body.add_child(UITheme.button("Setări", func() -> void: HUD.open_panel(SettingsPanel.new())))
	body.add_child(UITheme.button("Comenzi", func() -> void: HUD.open_panel(ControlsPanel.new())))
	body.add_child(UITheme.button("Meniul principal", func() -> void:
		HUD.close_all_panels()
		Game.goto("menu")))
	body.add_child(UITheme.button("Ieșire pe desktop", func() -> void: get_tree().quit()))
