extends Node
## 0.65: where a frame goes, measured from inside the main loop (tests only). Two markers per loop stage, at the
## lowest and highest process priorities, split each frame into:
##   phys_scripts  every node's _physics_process (and internal physics process)
##   phys_engine   from the last physics script to the next idle step: the physics server's step (Jolt) + sync
##   process       every node's _process and internal process (AnimationPlayer/Tree, skeletons, particles, audio)
##   render        from the end of process to the next frame's first marker: culling, draw submission, swap
## Each is a per-frame average over the window between `begin()` and `take()`.

var _first: Node
var _last: Node
var _pfirst: Node
var _plast: Node
var phys_scripts := 0.0
var phys_engine := 0.0
var process := 0.0
var render := 0.0
var frames := 0
var steps := 0
var _t_phys_end := 0
var _t_proc_end := 0
var _t_phys_start := 0
var _t_proc_start := 0
var _pending_engine := false
var _pending_render := false
var on := false
## Frames longer than SPIKE_MS: [total, physics scripts, physics engine, process, render before it] (ms).
const SPIKE_MS := 25.0
var spikes: Array = []
var _f_scripts := 0
var _f_engine := 0
var _f_render := 0
var _f_start := 0

class Mark extends Node:
	var cb: Callable
	var phys := false
	func _init(callback: Callable, physics: bool, priority: int) -> void:
		cb = callback
		phys = physics
		if physics: process_physics_priority = priority
		else: process_priority = priority
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _physics_process(_d: float) -> void:
		if phys: cb.call()
	func _process(_d: float) -> void:
		if not phys: cb.call()

func _ready() -> void:
	name = "FrameAnatomy"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_physics_process(false)
	add_child(Mark.new(_phys_start, true, -2147483647))
	add_child(Mark.new(_phys_end, true, 2147483647))
	add_child(Mark.new(_proc_start, false, -2147483647))
	add_child(Mark.new(_proc_end, false, 2147483647))

func begin() -> void:
	phys_scripts = 0.0
	phys_engine = 0.0
	process = 0.0
	render = 0.0
	frames = 0
	steps = 0
	_pending_engine = false
	_pending_render = false
	spikes.clear()
	on = true

func take() -> Dictionary:
	on = false
	var n := maxf(1.0, float(frames))
	return {"a_phys_scripts_ms": snappedf(phys_scripts / n / 1000.0, .01), "a_phys_engine_ms": snappedf(phys_engine / n / 1000.0, .01),
		"a_process_ms": snappedf(process / n / 1000.0, .01), "a_render_ms": snappedf(render / n / 1000.0, .01),
		"a_steps": snappedf(steps / n, .01), "spikes": spikes.slice(0, 8)}

func _phys_start() -> void:
	var now := Time.get_ticks_usec()
	if on and _pending_engine:
		# A second physics step in the same frame: the engine step of the previous one ran in between.
		phys_engine += now - _t_phys_end
		_f_engine += now - _t_phys_end
		_pending_engine = false
	if on and _pending_render:
		render += now - _t_proc_end
		_f_render += now - _t_proc_end
		_pending_render = false
	_t_phys_start = now

func _phys_end() -> void:
	var now := Time.get_ticks_usec()
	if on:
		phys_scripts += now - _t_phys_start
		_f_scripts += now - _t_phys_start
		steps += 1
		_pending_engine = true
	_t_phys_end = now

func _proc_start() -> void:
	var now := Time.get_ticks_usec()
	if on and _pending_engine:
		phys_engine += now - _t_phys_end
		_f_engine += now - _t_phys_end
		_pending_engine = false
	if on and _pending_render:
		render += now - _t_proc_end
		_f_render += now - _t_proc_end
		_pending_render = false
	_t_proc_start = now

func _proc_end() -> void:
	var now := Time.get_ticks_usec()
	if on:
		process += now - _t_proc_start
		frames += 1
		_pending_render = true
		var total := (now - _f_start) / 1000.0
		if _f_start > 0 and total > SPIKE_MS:
			spikes.append([snappedf(total, .1), snappedf(_f_scripts / 1000.0, .1), snappedf(_f_engine / 1000.0, .1), snappedf((now - _t_proc_start) / 1000.0, .1), snappedf(_f_render / 1000.0, .1)])
	_f_start = now
	_f_scripts = 0
	_f_engine = 0
	_f_render = 0
	_t_proc_end = now
