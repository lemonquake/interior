"""Summarize matched desktop Compatibility runs; never label these as phone FPS."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "docs/mobile-performance"
before = json.loads((DIRECTORY / "baseline-warm/report.json").read_text())
after = json.loads((DIRECTORY / "final/report.json").read_text())
rows = []
for old, new in zip(before["views"], after["views"]):
    if old["view"] != new["view"]:
        raise ValueError("Camera routes differ")
    if old["view"] == "basement":
        continue  # The final audit corrects this camera to the cellar floor.
    rows.append({"view": old["view"], "before_ms": old["median_ms"],
                 "after_ms": new["median_ms"],
                 "median_frame_time_reduction_percent": round(100*(1-new["median_ms"]/old["median_ms"]),1),
                 "before_draw_calls": old["mean_draws"], "after_draw_calls":new["mean_draws"],
                 "before_primitives": old["mean_primitives"], "after_primitives":new["mean_primitives"]})
memory_before = max(x["video_memory_mb"] for x in before["views"])
memory_after = max(x["video_memory_mb"] for x in after["views"])
report = {"source":"Windows editor runtime, Compatibility, 1280x720, Low, uncapped; desktop GPU",
          "physical_phone_measured":False,"adapter":after["adapter"],"views":rows,
          "reported_graphics_memory_mb":{"before":memory_before,"after":memory_after,
             "reduction_percent":round(100*(1-memory_after/memory_before),1)},
          "scene_setup_ms":{"before":before["boot_ms"],"after":after["boot_ms"]},
          "limits":"Short steady samples after >=90 warmup frames; does not establish phone FPS, thermal stability, or startup guarantees. Separate cold traversal preserved. Final Android export uses additional texture downsizing."}
(DIRECTORY / "comparison.json").write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ("views",)}))
