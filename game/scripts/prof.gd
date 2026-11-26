class_name InteriorProf
extends RefCounted
## 0.43: script time per callback, filled only while tools/prof_frame.py has wrapped the scripts. `-- --prof` prints
## the biggest every two seconds (milliseconds per frame).

static var _totals := {}
static var _calls := {}
static var _frames := 0
static var _since := 0
## 0.65: this frame's totals; a frame whose script time passes SPIKE_US prints its biggest.
static var _frame := {}
const SPIKE_US := 6000

static func add(key: String, usec: int) -> void:
	_totals[key] = int(_totals.get(key, 0)) + usec
	_calls[key] = int(_calls.get(key, 0)) + 1
	var frame := Engine.get_process_frames()
	if frame != _since:
		var sum := 0
		var top: Array = []
		for k: String in _frame:
			sum += int(_frame[k])
			top.append([int(_frame[k]), k])
		if sum > SPIKE_US:
			top.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			print("INTERIOR_PROF_SPIKE %.1f ms | %s" % [sum / 1000.0, ", ".join(top.slice(0, 10).map(func(r: Array) -> String: return "%s %.2f" % [r[1], r[0] / 1000.0]))])
		_frame.clear()
		_since = frame
		_frame[key] = usec
		_frames += 1
		if _frames >= 240:
			var rows: Array = []
			for k: String in _totals:
				rows.append([float(_totals[k]) / _frames / 1000.0, k, float(_calls[k]) / _frames])
			rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			var total := 0.0
			for r: Array in rows:
				total += float(r[0])
			var parts: Array = []
			for r: Array in rows.slice(0, 30):
				parts.append("%s %.3f x%.1f" % [r[1], r[0], r[2]])
			print("INTERIOR_PROF total %.2f ms | %s" % [total, ", ".join(parts)])
			_totals.clear()
			_calls.clear()
			_frames = 0
		return
	_frame[key] = int(_frame.get(key, 0)) + usec
