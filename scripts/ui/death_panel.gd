class_name DeathPanel
extends UIPanel

const REASONS := {
	"shockwave": "Unda de șoc te-a prins la suprafață.",
	"starvation": "Corpul a cedat: foame, sete sau epuizare.",
	"radiation": "Doza de radiație a fost letală.",
	"air": "Aerul din buncăr a devenit irespirabil. Filtrul FVU trebuia schimbat.",
	"suffocation": "Filtrul s-a terminat. Aerul de afară te-a ucis.",
	"enemy": "Ai fost ucis la suprafață.",
	"bleed": "Ai sângerat până la moarte. Bandajele salvează vieți.",
}

var reason := ""
var retry: Callable


func _init(p_reason: String, p_retry: Callable) -> void:
	super("", 680.0)
	reason = p_reason
	retry = p_retry
	dim.color = Color(0.08, 0, 0, 0.82)
	header.visible = false


func build() -> void:
	var t := UITheme.heading("Ai murit", 64, UITheme.DANGER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)
	var l := UITheme.label(REASONS.get(reason, "Lumea de după nu iartă."), 22, UITheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 640
	body.add_child(l)
	body.add_child(UITheme.label("Ai supraviețuit %d zile." % maxi(State.day - 1, 0), 18, UITheme.TEXT_DIM))
	body.add_child(UITheme.spacer(10))
	body.add_child(UITheme.button("Reîncearcă" if State.context == "intro" else "Încarcă ultima salvare", func() -> void:
		HUD.close_all_panels()
		retry.call()))
	body.add_child(UITheme.button("Meniul principal", func() -> void:
		HUD.close_all_panels()
		Game.goto("menu")))


func close() -> void:
	pass  # cannot be dismissed with Esc
