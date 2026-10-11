extends SceneTree

# EditorExport is internal C++, not a GDScript API. Inspect the config safely.
# Actual template / SDK / signing validation remains the export command's job.
func _initialize() -> void:
    var config := ConfigFile.new()
    var error := config.load("res://export_presets.cfg")
    if error != OK:
        push_error("MCX_DIAG: Cannot load export presets: %d" % error)
        quit(1)
        return
    var android_found := false
    for section in config.get_sections():
        if not section.begins_with("preset.") or section.ends_with(".options"):
            continue
        var platform := str(config.get_value(section, "platform", ""))
        print("MCX_DIAG: Preset: ", config.get_value(section, "name", ""), " platform: ", platform)
        if platform == "Android":
            android_found = true
            var options := section + ".options"
            print("MCX_DIAG: Android version: ", config.get_value(options, "version/name", ""))
            print("MCX_DIAG: Android package: ", config.get_value(options, "package/unique_name", ""))
    if not android_found:
        push_error("MCX_DIAG: Android preset is missing")
    quit(0 if android_found else 1)
