#!/usr/bin/env python3
"""Run inside the Bottles flatpak:  list | show <dep> | install <bottle> <dep>..."""
import sys, warnings
warnings.filterwarnings("ignore")
sys.path.insert(1, "/app/share/bottles")
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gio
from bottles.backend.managers.manager import Manager

mng = Manager(g_settings=Gio.Settings.new("com.usebottles.bottles"), is_cli=True)
dm = mng.dependency_manager
cmd = sys.argv[1]
if cmd == "list":
    for name, info in sorted(dm.fetch_catalog().items()):
        print(f"{name}\t{info.get('Category','')}\t{info.get('Description','')}")
elif cmd == "show":
    import json; print(json.dumps(dm.get_dependency(sys.argv[2]), indent=1, default=str))
elif cmd == "install":
    mng.check_bottles(silent=True)
    cfg = mng.local_bottles[sys.argv[2]]
    for dep in sys.argv[3:]:
        r = dm.install(cfg, [dep, dm.get_dependency(dep)], progress_cb=print)
        print("RESULT", dep, r.status, r.message)
        cfg = mng.local_bottles.get(sys.argv[2], cfg)
elif cmd == "runners":
    cat = mng.component_manager.fetch_catalog()
    for kind in ("wine", "proton"):
        for name, info in cat.get(kind, {}).items():
            print(kind, name, info.get("Channel", ""), info.get("Installed", ""), sep="\t")
elif cmd == "show-runner":
    import json; print(json.dumps(mng.component_manager.get_component(sys.argv[2]), indent=1, default=str))
elif cmd == "install-runner":
    r = mng.component_manager.install("runner", sys.argv[2])
    print("RESULT", r)
