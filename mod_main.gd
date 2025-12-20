extends Node

# TajsModded Mod - Upload Labs
# Autor: TajemnikTV

const MOD_DIR := "TajemnikTV-TajsModded"
const LOG_NAME := "TajemnikTV-TajsModded:Main"
const CONFIG_PATH := "user://TajsModded_config.json"

var mod_dir_path := ""
var settings_button: Button = null
var settings_panel: PanelContainer = null
var is_ready := false
var is_animating := false  # Blokada podczas animacji

# Konfiguracja moda (zapisywana do pliku)
var mod_config := {
    "option1": false,
    "option2": false,
    "option3": 50.0
}


func _init() -> void:
    ModLoaderLog.info("TajsModded Initialization...", LOG_NAME)
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    load_config()


func _ready() -> void:
    ModLoaderLog.info("TajsModded ready!", LOG_NAME)
    
    # Czekamy na załadowanie się gry - nasłuchujemy gdy Main zostanie dodany
    get_tree().node_added.connect(_on_node_added)
    
    # Sprawdź czy Main już istnieje (mod może się załadować po głównej scenie)
    call_deferred("_check_existing_main")


func _check_existing_main() -> void:
    if is_ready:
        return
    
    var main_node := get_tree().root.get_node_or_null("Main")
    if main_node:
        ModLoaderLog.info("Main node found on startup, setting up...", LOG_NAME)
        # Poczekaj chwilę na pełne załadowanie HUD
        await get_tree().create_timer(0.5).timeout
        if is_instance_valid(main_node) and !is_ready:
            setup_mod_button(main_node)
            is_ready = true


func _on_node_added(node: Node) -> void:
    if is_ready:
        return
    
    # Szukamy HUD, który jest częścią Main
    if node.name == "Main" and node.get_parent().name == "root":
        ModLoaderLog.info("Main node detected via node_added signal!", LOG_NAME)
        # Poczekaj chwilę na pełne załadowanie HUD
        await get_tree().create_timer(0.5).timeout
        if is_instance_valid(node) and !is_ready:
            setup_mod_button(node)
            is_ready = true


func setup_mod_button(main: Node) -> void:
    # Znajdź HUD i kontener z przyciskami extras (prawy górny róg)
    var hud := main.get_node_or_null("HUD")
    if !hud:
        ModLoaderLog.warning("HUD not found!", LOG_NAME)
        return
    
    var extras_container := hud.get_node_or_null("Main/MainContainer/Overlay/ExtrasButtons/Container")
    if !extras_container:
        ModLoaderLog.warning("ExtrasButtons container not found!", LOG_NAME)
        return
    
    # Stwórz przycisk ustawień moda (styl zgodny z istniejącymi przyciskami)
    settings_button = Button.new()
    settings_button.name = "TajsModdedSettings"
    settings_button.custom_minimum_size = Vector2(80, 80)
    settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
    settings_button.focus_mode = Control.FOCUS_NONE
    settings_button.theme_type_variation = "ButtonMenu"
    settings_button.toggle_mode = true
    settings_button.icon = load("res://textures/icons/puzzle.png")  # Puzzle = mody/extensions
    settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    settings_button.expand_icon = true
    settings_button.tooltip_text = "TajsModded Mod Settings"
    
    # Dodaj na początek listy (przed innymi przyciskami)
    extras_container.add_child(settings_button)
    extras_container.move_child(settings_button, 0)
    
    # Podłącz sygnał
    settings_button.pressed.connect(_on_settings_button_pressed)
    
    # Stwórz panel ustawień (początkowo ukryty)
    create_settings_panel(hud)
    
    ModLoaderLog.info("Mod button added to UI!", LOG_NAME)


func create_settings_panel(hud: Node) -> void:
    # Panel główny z cieniem (styl zgodny z grą)
    settings_panel = PanelContainer.new()
    settings_panel.name = "TajsModdedSettingsPanel"
    settings_panel.visible = false
    settings_panel.theme_type_variation = "ShadowPanelContainer"
    settings_panel.custom_minimum_size = Vector2(400, 0)
    
    # Pozycjonowanie w prawym górnym rogu (obok przycisków extras)
    settings_panel.anchor_left = 1.0
    settings_panel.anchor_right = 1.0
    settings_panel.anchor_top = 0.0
    settings_panel.anchor_bottom = 0.0
    settings_panel.offset_left = -520
    settings_panel.offset_right = -120
    settings_panel.offset_top = 10
    settings_panel.offset_bottom = 400
    
    # Początkowa pozycja dla animacji (poza ekranem)
    settings_panel.modulate.a = 0
    
    # Kontener główny (VBox)
    var main_vbox := VBoxContainer.new()
    main_vbox.name = "MainVBox"
    main_vbox.add_theme_constant_override("separation", -1)
    settings_panel.add_child(main_vbox)
    
    # ===== NAGŁÓWEK (TitlePanel) =====
    var title_panel := Panel.new()
    title_panel.name = "TitlePanel"
    title_panel.custom_minimum_size = Vector2(0, 80)
    title_panel.theme_type_variation = "OverlayPanelTitle"
    main_vbox.add_child(title_panel)
    
    var title_container := HBoxContainer.new()
    title_container.name = "TitleContainer"
    title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    title_container.offset_left = 15
    title_container.offset_top = 15
    title_container.offset_right = -15
    title_container.offset_bottom = -15
    title_container.add_theme_constant_override("separation", 10)
    title_container.alignment = BoxContainer.ALIGNMENT_CENTER
    title_panel.add_child(title_container)
    
    # Ikona w nagłówku
    var title_icon := TextureRect.new()
    title_icon.name = "TitleIcon"
    title_icon.custom_minimum_size = Vector2(48, 48)
    title_icon.texture = load("res://textures/icons/puzzle.png")
    title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    title_icon.self_modulate = Color(0.567, 0.69465, 0.9, 1)  # Niebieski odcień jak w grze
    title_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    title_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    title_container.add_child(title_icon)
    
    # Tytuł
    var title_label := Label.new()
    title_label.name = "TitleLabel"
    title_label.text = "Taj's Mod"
    title_label.add_theme_font_size_override("font_size", 40)
    title_container.add_child(title_label)
    
    # ===== ZAWARTOŚĆ (MenuPanel) =====
    var content_panel := PanelContainer.new()
    content_panel.name = "ContentPanel"
    content_panel.theme_type_variation = "MenuPanel"
    content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_vbox.add_child(content_panel)
    
    var content_margin := MarginContainer.new()
    content_margin.name = "ContentMargin"
    content_margin.add_theme_constant_override("margin_left", 15)
    content_margin.add_theme_constant_override("margin_top", 15)
    content_margin.add_theme_constant_override("margin_right", 15)
    content_margin.add_theme_constant_override("margin_bottom", 15)
    content_panel.add_child(content_margin)
    
    var content := VBoxContainer.new()
    content.name = "SettingsContent"
    content.add_theme_constant_override("separation", 10)
    content_margin.add_child(content)
    
    # ----- Opcja 1: Toggle z etykietą -----
    var option1_row := HBoxContainer.new()
    option1_row.name = "Option1Row"
    option1_row.custom_minimum_size = Vector2(0, 64)
    content.add_child(option1_row)
    
    var option1_label := Label.new()
    option1_label.text = "Switch 1"
    option1_label.add_theme_font_size_override("font_size", 32)
    option1_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    option1_row.add_child(option1_label)
    
    var option1_toggle := CheckButton.new()
    option1_toggle.name = "Option1Toggle"
    option1_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
    option1_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    option1_toggle.focus_mode = Control.FOCUS_NONE
    option1_toggle.flat = true
    option1_toggle.toggled.connect(func(toggled): _on_option1_toggled(toggled))
    option1_row.add_child(option1_toggle)
    
    # ----- Opcja 2: Toggle z etykietą -----
    var option2_row := HBoxContainer.new()
    option2_row.name = "Option2Row"
    option2_row.custom_minimum_size = Vector2(0, 64)
    content.add_child(option2_row)
    
    var option2_label := Label.new()
    option2_label.text = "Switch 2"
    option2_label.add_theme_font_size_override("font_size", 32)
    option2_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    option2_row.add_child(option2_label)
    
    var option2_toggle := CheckButton.new()
    option2_toggle.name = "Option2Toggle"
    option2_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
    option2_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    option2_toggle.focus_mode = Control.FOCUS_NONE
    option2_toggle.flat = true
    option2_toggle.toggled.connect(func(toggled): _on_option2_toggled(toggled))
    option2_row.add_child(option2_toggle)
    
    # ----- Opcja 3: Slider -----
    var option3_container := VBoxContainer.new()
    option3_container.name = "Option3Container"
    option3_container.add_theme_constant_override("separation", 10)
    content.add_child(option3_container)
    
    var option3_header := HBoxContainer.new()
    option3_header.name = "Option3Header"
    option3_container.add_child(option3_header)
    
    var option3_label := Label.new()
    option3_label.text = "Slider Value"
    option3_label.add_theme_font_size_override("font_size", 32)
    option3_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    option3_header.add_child(option3_label)
    
    var option3_value := Label.new()
    option3_value.name = "Option3Value"
    option3_value.text = "50"
    option3_value.add_theme_font_size_override("font_size", 32)
    option3_header.add_child(option3_value)
    
    var option3_slider := HSlider.new()
    option3_slider.name = "Option3Slider"
    option3_slider.min_value = 0
    option3_slider.max_value = 100
    option3_slider.value = 50
    option3_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    option3_slider.custom_minimum_size = Vector2(0, 30)
    option3_slider.value_changed.connect(func(value): _on_option3_changed(value))
    option3_container.add_child(option3_slider)
    
    # ----- Wersja na dole -----
    var version_label := Label.new()
    version_label.text = "Taj's Mod v0.0.1"
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.add_theme_color_override("font_color", Color(0.627, 0.776, 0.812, 1))
    version_label.add_theme_font_size_override("font_size", 18)
    content.add_child(version_label)
    
    # Dodaj panel do HUD
    var overlay := hud.get_node_or_null("Main/MainContainer/Overlay")
    if overlay:
        overlay.add_child(settings_panel)
    
    # Podłącz się do sygnałów gry dla auto-zamykania
    _connect_auto_close_signals()
    
    # Zastosuj zapisaną konfigurację do UI
    apply_config_to_ui()


func toggle_settings_panel(show: bool) -> void:
    if !settings_panel or is_animating:
        return
    
    # Zamknij inne menu gry gdy otwieramy nasz panel
    if show and Signals:
        Signals.set_menu.emit(0, 0)  # Utils.menu_types.NONE = 0
    
    is_animating = true
    
    if show:
        # Animacja otwierania (slide from right)
        settings_panel.visible = true
        settings_panel.modulate.a = 0
        settings_panel.offset_left = -420  # Start bliżej prawej krawędzi
        settings_panel.offset_right = -20
        
        var tween := create_tween()
        tween.set_parallel()
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(settings_panel, "modulate:a", 1.0, 0.15)
        tween.tween_property(settings_panel, "offset_left", -520, 0.25)
        tween.tween_property(settings_panel, "offset_right", -120, 0.25)
        tween.chain().tween_callback(func(): is_animating = false)
        
        Sound.play("menu_open")
    else:
        # Animacja zamykania (slide to right)
        var tween := create_tween()
        tween.set_parallel()
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.tween_property(settings_panel, "modulate:a", 0.0, 0.15)
        tween.tween_property(settings_panel, "offset_left", -420, 0.2)
        tween.tween_property(settings_panel, "offset_right", -20, 0.2)
        tween.chain().tween_callback(func():
            settings_panel.visible = false
            is_animating = false
        )
        
        Sound.play("menu_close")
    
    if settings_button:
        settings_button.button_pressed = show


func _on_settings_button_pressed() -> void:
    toggle_settings_panel(!settings_panel.visible if settings_panel else false)
    Sound.play("click_toggle")


# ===== HANDLERS DLA OPCJI =====
# Tutaj dodaj logikę dla swoich opcji

func _on_option1_toggled(enabled: bool) -> void:
    mod_config["option1"] = enabled
    save_config()
    ModLoaderLog.info("Option 1: " + str(enabled), LOG_NAME)
    # TODO: Twoja logika dla opcji 1


func _on_option2_toggled(enabled: bool) -> void:
    mod_config["option2"] = enabled
    save_config()
    ModLoaderLog.info("Option 2: " + str(enabled), LOG_NAME)
    # TODO: Twoja logika dla opcji 2


func _on_option3_changed(value: float) -> void:
    mod_config["option3"] = value
    save_config()
    ModLoaderLog.info("Option 3 value: " + str(value), LOG_NAME)
    # Aktualizuj label z wartością
    if settings_panel:
        var slider_value := settings_panel.get_node_or_null("MainVBox/ContentPanel/ContentMargin/SettingsContent/Option3Container/Option3Header/Option3Value")
        if slider_value:
            slider_value.text = str(int(value))
    # TODO: Twoja logika dla opcji 3
    Sound.play("click")


# ===== SAVE/LOAD CONFIG =====

func save_config() -> void:
    var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(mod_config, "  "))
        file.close()
        ModLoaderLog.debug("Config saved to " + CONFIG_PATH, LOG_NAME)


func load_config() -> void:
    if FileAccess.file_exists(CONFIG_PATH):
        var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
        if file:
            var json_string := file.get_as_text()
            file.close()
            var json := JSON.new()
            if json.parse(json_string) == OK:
                var data = json.get_data()
                if data is Dictionary:
                    # Merge loaded data with defaults (keeps new options working)
                    for key in data:
                        if mod_config.has(key):
                            mod_config[key] = data[key]
                    ModLoaderLog.info("Config loaded from " + CONFIG_PATH, LOG_NAME)
            else:
                ModLoaderLog.warning("Failed to parse config JSON", LOG_NAME)
    else:
        ModLoaderLog.info("No config file found, using defaults", LOG_NAME)


func apply_config_to_ui() -> void:
    if !settings_panel:
        return
    
    # Zastosuj wartości z konfiguracji do elementów UI
    var option1_toggle := settings_panel.get_node_or_null("MainVBox/ContentPanel/ContentMargin/SettingsContent/Option1Row/Option1Toggle")
    if option1_toggle:
        option1_toggle.button_pressed = mod_config["option1"]
    
    var option2_toggle := settings_panel.get_node_or_null("MainVBox/ContentPanel/ContentMargin/SettingsContent/Option2Row/Option2Toggle")
    if option2_toggle:
        option2_toggle.button_pressed = mod_config["option2"]
    
    var option3_slider := settings_panel.get_node_or_null("MainVBox/ContentPanel/ContentMargin/SettingsContent/Option3Container/Option3Slider")
    if option3_slider:
        option3_slider.value = mod_config["option3"]
    
    var option3_value := settings_panel.get_node_or_null("MainVBox/ContentPanel/ContentMargin/SettingsContent/Option3Container/Option3Header/Option3Value")
    if option3_value:
        option3_value.text = str(int(mod_config["option3"]))


func _connect_auto_close_signals() -> void:
    # Zamknij panel gdy użytkownik otworzy inne menu lub kliknie gdzie indziej
    if Signals:
        # Zamknij gdy zmieni się menu
        Signals.menu_set.connect(_on_menu_changed)
    
    # Zamknij gdy przyciski ExtrasButtons zostaną kliknięte (z wyjątkiem naszego)
    var extras_container := get_tree().root.get_node_or_null("Main/HUD/Main/MainContainer/Overlay/ExtrasButtons/Container")
    if extras_container:
        for child in extras_container.get_children():
            if child is Button and child != settings_button:
                child.pressed.connect(_on_other_button_pressed)


func _on_menu_changed(menu: int, _tab: int) -> void:
    # Zamknij panel gdy otwarte zostanie jakiekolwiek menu
    if menu != 0 and settings_panel and settings_panel.visible:
        toggle_settings_panel(false)


func _on_other_button_pressed() -> void:
    # Zamknij panel gdy kliknięto inny przycisk w ExtrasButtons
    if settings_panel and settings_panel.visible:
        toggle_settings_panel(false)
