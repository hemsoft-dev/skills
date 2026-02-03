import sys
from pyvda import AppView, get_apps_by_z_order, VirtualDesktop, get_virtual_desktops

direction = sys.argv[1] if len(sys.argv) > 1 else "Next"
current = VirtualDesktop.current()
desktops = get_virtual_desktops()
current_index = desktops.index(current)

if direction == "Next":
    target_index = (current_index + 1) % len(desktops)
else:
    target_index = (current_index - 1) % len(desktops)

desktops[target_index].go()
