extends SceneTree

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
    var ui = load("res://scenes/main.tscn").instantiate()
    root.add_child(ui)
    ui.set_process(false)
    await snap("home")
    ui._new_campaign()
    await snap("selection")
    ui._start_selected_round()
    for _frame in range(300):
        ui._process(1.0 / 30.0)
    await snap("battle")
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
    ui._show_home()
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    await snap("exit-confirmation-narrow")
    ui.free()
    print("PREVIEW_CAPTURE: 7 desktop images saved in build/qa")
    quit()

func snap(name: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png("res://build/qa/" + name + ".png")
    if error != OK:
        push_error("Preview save failed: %s" % name)
        quit(1)
