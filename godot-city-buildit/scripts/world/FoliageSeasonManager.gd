extends Node
class_name FoliageSeasonManager

signal season_changed(season: int)
signal transition_finished(season: int)

enum Season {
    SPRING,
    SUMMER,
    AUTUMN,
    WINTER
}

var _foliage_material: ShaderMaterial
var _leaf_emitters: Array[CPUParticles3D] = []
var _transition: Tween
var current_season: Season = Season.SUMMER


func configure(material: ShaderMaterial, emitters: Array[CPUParticles3D]) -> void:
    _foliage_material = material
    _leaf_emitters = emitters
    _apply_immediately(current_season)


func change_season(next_season: int, duration: float = 8.0) -> void:
    if next_season < Season.SPRING or next_season > Season.WINTER:
        push_warning("FoliageSeasonManager: Invalid season index.")
        return
    if _foliage_material == null:
        return

    current_season = next_season
    if _transition != null and _transition.is_running():
        _transition.kill()

    var target_tint := _season_tint(current_season)
    var target_density := _season_density(current_season)
    var target_snow := 0.0
    var target_fall := 0.0

    if current_season == Season.AUTUMN:
        target_fall = 0.48
    elif current_season == Season.WINTER:
        target_snow = 0.58
        target_fall = 0.10

    season_changed.emit(current_season)
    _transition = create_tween()
    _transition.set_trans(Tween.TRANS_SINE)
    _transition.set_ease(Tween.EASE_IN_OUT)
    var safe_duration := maxf(duration, 0.05)

    _transition.tween_method(
        _set_seasonal_tint,
        _foliage_material.get_shader_parameter("seasonal_tint"),
        target_tint,
        safe_duration
    )
    _transition.parallel().tween_method(
        _set_leaf_density,
        float(_foliage_material.get_shader_parameter("leaf_density")),
        target_density,
        safe_duration
    )
    _transition.parallel().tween_method(
        _set_snow_amount,
        float(_foliage_material.get_shader_parameter("snow_amount")),
        target_snow,
        safe_duration
    )
    _transition.parallel().tween_method(
        _set_leaf_fall_ratio,
        _current_leaf_fall_ratio(),
        target_fall,
        safe_duration
    )
    _transition.tween_callback(_finish_transition.bind(current_season))


func _apply_immediately(season: Season) -> void:
    if _foliage_material == null:
        return
    _foliage_material.set_shader_parameter("seasonal_tint", _season_tint(season))
    _foliage_material.set_shader_parameter("leaf_density", _season_density(season))
    _foliage_material.set_shader_parameter("snow_amount", 0.58 if season == Season.WINTER else 0.0)
    _set_leaf_fall_ratio(0.48 if season == Season.AUTUMN else 0.10 if season == Season.WINTER else 0.0)


func _season_tint(season: Season) -> Color:
    match season:
        Season.SPRING:
            return Color(1.13, 1.16, 0.82, 1.0)
        Season.SUMMER:
            return Color(1.0, 1.0, 1.0, 1.0)
        Season.AUTUMN:
            return Color(1.34, 0.76, 0.43, 1.0)
        Season.WINTER:
            return Color(0.66, 0.76, 0.78, 1.0)
    return Color.WHITE


func _season_density(season: Season) -> float:
    match season:
        Season.SPRING:
            return 0.82
        Season.SUMMER:
            return 1.0
        Season.AUTUMN:
            return 0.84
        Season.WINTER:
            return 0.28
    return 1.0


func _set_seasonal_tint(value: Color) -> void:
    _foliage_material.set_shader_parameter("seasonal_tint", value)


func _set_leaf_density(value: float) -> void:
    _foliage_material.set_shader_parameter("leaf_density", value)


func _set_snow_amount(value: float) -> void:
    _foliage_material.set_shader_parameter("snow_amount", value)


func _set_leaf_fall_ratio(value: float) -> void:
    for emitter in _leaf_emitters:
        if not is_instance_valid(emitter):
            continue
        emitter.amount_ratio = clampf(value, 0.0, 1.0)
        emitter.emitting = value > 0.01


func _current_leaf_fall_ratio() -> float:
    if _leaf_emitters.is_empty():
        return 0.0
    return _leaf_emitters[0].amount_ratio


func _finish_transition(season: Season) -> void:
    transition_finished.emit(season)
