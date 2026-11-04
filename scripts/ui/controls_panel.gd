class_name ControlsPanel
extends UIPanel

const ROWS := [
	["W A S D", "Mișcare"], ["Shift", "Sprint"], ["Ctrl / C", "Ghemuit"], ["Space", "Săritură"],
	["E (ține apăsat)", "Interacțiune"], ["Tab / I", "Inventar"], ["B", "Mod construcție"],
	["G", "Mută mobila / lumina țintită (în buncăr)"], ["T", "Aliniere la grilă și perete (la plasare)"],
	["R", "Reîncărcare · Rotire 90° / întoarce la plasare"], ["F", "Lanternă"], ["1 / 2 / 3 / 4", "Topor / Pistol / AK-74M / Saiga-12"],
	["Rotița mouse-ului", "Schimbă arma · Rotește la plasare"], ["Click stânga", "Foc / Atac · Plasare"], ["Click dreapta", "Ochire (ADS) · Anulează plasarea"],
	["M", "Harta PDA a zonei"], ["U", "Dezvoltarea buncărului"], ["X", "Demontează o construcție"],
	["H", "Folosește bandaj"], ["Esc", "Pauză / închide"],
]


func _init() -> void:
	super("Comenzi", 640.0)


func build() -> void:
	for r in ROWS:
		var row := HBoxContainer.new()
		var k := UITheme.label(r[0], 19, UITheme.ACCENT, "bold")
		k.custom_minimum_size.x = 230
		row.add_child(k)
		row.add_child(UITheme.label(r[1], 19))
		body.add_child(row)
