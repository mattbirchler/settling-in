# dmgbuild settings for Settling In's disk image. scripts/make-dmg.sh passes
# the app and the background in with -D app=… -D background=….
# The icon positions must match the spots in scripts/dmg-background.swift.
import os
import plistlib

app = defines["app"]  # noqa: F821 (dmgbuild provides `defines`)
app_name = os.path.basename(app)

format = "ULFO"  # LZFSE: small, opens on any Mac Settling In runs on
filesystem = "APFS"
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = [app_name]

# The disk shows the app's icon on the desktop and in the sidebar.
with open(os.path.join(app, "Contents/Info.plist"), "rb") as f:
    icon_file = plistlib.load(f).get("CFBundleIconFile")
if icon_file:
    icon = os.path.join(app, "Contents/Resources", icon_file if icon_file.endswith(".icns") else icon_file + ".icns")

background = defines["background"]  # noqa: F821
window_rect = ((200, 120), (640, 432))  # 400 plus the title bar
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 112
text_size = 13
icon_locations = {
    app_name: (160, 180),
    "Applications": (480, 180),
}
