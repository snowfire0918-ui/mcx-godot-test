extends SceneTree

const SAVE := "user://preview-v0011.json"

func scene():
    var ui = load("res://scenes/main.tscn").instantiate()
    ui.save_path = SAVE
    root.add_child(ui)
    ui.set_process(false)
    return ui

# Desktop QA only. Run with a display; these captures do not prove Android rendering.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Preview capture requires a display, not --headless.")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute("res://build/qa")
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(720, 1280)
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        DirAccess.remove_absolute(SAVE + suffix)
    var ui = scene()
    await snap("home")
    ui._new_campaign()
    ui._show_rpg()
    ui.rpg_panel.target()["hp"] = 120.0
    ui.rpg_panel.target()["mp"] = 45.0
    ui.rpg_panel.support_picker.select(5)
    ui.rpg_panel.apply_support()
    await snap("rpg")
    ui.scroll.scroll_vertical = int(ui.scroll.get_v_scroll_bar().max_value)
    await snap("items")
    ui._show_home()
    ui._resume_campaign()
    await snap("selection")
    ui._start_selected_round()
    for _frame in range(300):
        ui._process(1.0 / 30.0)
    await snap("battle")
    ui._show_home()
    ui.free()
    ui = scene()
    await snap("restored-home")
    ui._resume_campaign()
    ui.campaign.elapsed = 99.0
    ui._process(0.0)
    await snap("withdrawal")
    ui._show_home()
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    await snap("exit-confirmation")
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    ui._show_selection()
    root.size = Vector2i(360, 800)
    await snap("selection-narrow")
    ui._show_rpg()
    await snap("rpg-narrow")
    ui.scroll.scroll_vertical = int(ui.scroll.get_v_scroll_bar().max_value)
    await snap("items-narrow")
    ui._show_home()
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    await snap("exit-confirmation-narrow")
    ui.free()
    print("PREVIEW_CAPTURE: 12 desktop images saved in build/qa")
    quit()

func snap(name: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png("res://build/qa/" + name + ".png")
    if error != OK:
        push_error("Preview save failed: %s" % name)
        quit(1)
