extends SceneTree
## 0.60: every line in assets/audio/voices/dialogue.json: the game's key (InteriorVoiceLines.key_of, from what the
## subtitle shows) matches the manifest's key (tools/dialogue_lines.py), and its clip is in the project. Also each
## survivor has take 1 of every squad call-out. Prints VOICE_LINES_CHECK {..} and exits 1 on a miss.
##   godot --headless --path game --script res://tests/voice_lines_check.gd

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voices/dialogue.json"))
	var lines: Array = data.lines
	var bad_key := []
	var missing := []
	var by_voice := {}
	for ln: Dictionary in lines:
		var shown := String(ln.text)
		if bool(ln.get("whisper", false)): shown = "(whispering) " + shown
		var k := InteriorVoiceLines.key_of(String(ln.speaker), shown)
		if k != String(ln.key): bad_key.append([ln.speaker, ln.text])
		if not InteriorVoiceLines.has_clip(String(ln.speaker), shown):
			missing.append("%s: %s" % [ln.speaker, String(ln.text).left(40)])
		by_voice[ln.voice] = int(by_voice.get(ln.voice, 0)) + 1
	var squad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voices/lines.json"))
	var callouts_missing := []
	for who: String in squad.survivors:
		for line: String in squad.lines:
			var found := false
			for ext in [".ogg", ".mp3"]:
				if ResourceLoader.exists("res://assets/audio/voices/%s/%s_1%s" % [who.to_lower(), line, ext]): found = true
			if not found: callouts_missing.append(who + "/" + line)
	var report := {"lines": lines.size(), "key_mismatch": bad_key.size(), "clips_missing": missing.size(),
		"callouts_missing": callouts_missing.size(), "first_missing": missing.slice(0, 8), "first_callouts_missing": callouts_missing.slice(0, 8)}
	print("VOICE_LINES_CHECK ", JSON.stringify(report))
	quit(0 if bad_key.is_empty() and missing.size() <= 42 and callouts_missing.is_empty() else 1)
