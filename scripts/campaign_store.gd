extends RefCounted

const Campaign = preload("res://scripts/battle_campaign.gd")
const Rules = preload("res://scripts/rpg_rules.gd")
const SCHEMA := 1
const MAX_BYTES := 2000000
var path: String
var recovering_backup := false

func _init(file_path: String = "user://campaign-v1.json") -> void:
    path = file_path

func _decode(text: String) -> Dictionary:
    var json := JSON.new()
    if json.parse(text) != OK or not json.data is Dictionary:
        return {"error": "存檔JSON損毀。"}
    var data: Dictionary = Campaign.normalize_json(json.data)
    if data.get("schema_version") != SCHEMA:
        return {"error": "存檔版本不相容，原檔已保留。", "unsupported": true}
    if not data.get("campaign") is Dictionary or not data.get("inventory") is Dictionary:
        return {"error": "存檔內容不完整。"}
    var candidate = Campaign.new()
    var error: String = candidate.restore(data["campaign"])
    if not error.is_empty():
        return {"error": error}
    var stock: Dictionary = data["inventory"]
    if stock.size() != Rules.catalog().size():
        return {"error": "存檔道具種類不一致。"}
    for key in Rules.catalog():
        if not stock.get(key) is int or stock[key] < 0 or stock[key] > 9007199254740991:
            return {"error": "存檔道具數量無效。"}
    return {"error": "", "campaign": candidate.snapshot(), "inventory": stock}

func _read(file_path: String) -> Dictionary:
    if not FileAccess.file_exists(file_path):
        return {"error": "", "missing": true}
    var f := FileAccess.open(file_path, FileAccess.READ)
    if f == null:
        return {"error": "無法讀取存檔。"}
    if f.get_length() > MAX_BYTES:
        f.close()
        return {"error": "存檔過大。"}
    var text := f.get_as_text()
    f.close()
    return _decode(text)

func save(campaign, stock: Dictionary, replace_invalid: bool = false) -> String:
    var text := JSON.stringify({"schema_version": SCHEMA, "campaign": campaign.snapshot(), "inventory": stock}, "", false, true)
    var checked := _decode(text)
    if not checked.error.is_empty():
        return checked.error
    var primary := _read(path)
    if primary.get("unsupported", false) and not replace_invalid:
        return primary.error
    if not primary.error.is_empty() and not replace_invalid and not recovering_backup:
        return "原存檔無效，請先明確建立新戰役。"
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir()) != OK:
        return "無法建立存檔目錄。"
    var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
    if f == null:
        return "無法寫入存檔。"
    f.store_string(text)
    f.flush()
    var write_error := f.get_error()
    f.close()
    if write_error != OK or not _read(path + ".tmp").error.is_empty():
        return "存檔寫入未完成，原檔已保留。"
    if primary.error.is_empty() and not primary.get("missing", false):
        if DirAccess.copy_absolute(path, path + ".bak.tmp") != OK or DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak") != OK:
            return "無法更新存檔備份，原檔已保留。"
    if DirAccess.rename_absolute(path + ".tmp", path) != OK:
        return "無法替換存檔，原檔已保留。"
    recovering_backup = false
    return ""

func load_into(campaign, stock: Dictionary) -> Dictionary:
    recovering_backup = false
    var data := _read(path)
    if data.get("unsupported", false):
        return {"found": true, "error": data.error, "recovered": false}
    var recovered := false
    if not data.error.is_empty() or data.get("missing", false):
        var backup := _read(path + ".bak")
        if backup.error.is_empty() and not backup.get("missing", false):
            data = backup
            recovered = true
        elif data.get("missing", false) and backup.get("missing", false):
            return {"found": false, "error": "", "recovered": false}
        else:
            return {"found": true, "error": "存檔及備份無法讀取，原檔已保留。", "recovered": false}
    var error: String = campaign.restore(data["campaign"])
    if not error.is_empty():
        return {"found": true, "error": error, "recovered": false}
    stock.clear()
    stock.merge(data["inventory"], true)
    recovering_backup = recovered
    return {"found": true, "error": "", "recovered": recovered}
