extends SceneTree

func _initialize() -> void:
    var export_api := EditorExport
    print("MCX_DIAG: Export preset count: ", export_api.get_export_presets().size())
    for preset in export_api.get_export_presets():
        print("MCX_DIAG: Preset: ", preset.get_name(), " platform: ", preset.get_platform().get_name())
        var platform := preset.get_platform()
        var errors := []
        var missing_templates := false
        var ok := platform.can_export(preset, true)
        print("MCX_DIAG: can_export: ", ok)
        for prop in platform.get_export_options():
            var key: String = prop.get("name", "")
            if key.is_empty():
                continue
            var warning: String = platform.get_option_warning(preset, key)
            if not warning.is_empty():
                print("MCX_DIAG: Warning for ", key, ": ", warning)
    quit()
