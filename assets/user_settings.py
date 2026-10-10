# Reference template. convert.sh generates this file inside the tool automatically,
# with ZLUDA64_PATH pointing at the tool's embedded ./zluda directory.
#
# Place a file named "user_settings.py" in the tool directory to have Proton apply
# these environment variables to the game.
user_settings = {
    # 32-bit ZLUDA nvcuda shim -> 64-bit ZLUDA server directory (Windows path under Wine).
    # convert.sh rewrites this to match the tool's install location.
    "ZLUDA64_PATH": "Z:\\home\\USER\\.local\\share\\Steam\\compatibilitytools.d\\ZludaProton\\zluda",
    # Useful for debugging (writes ~/steam-<AppID>.log).
    "PROTON_LOG": "1",
}
