package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue

internal fun JsonValue.Obj.objectOrNull(name: String): JsonValue.Obj? = this[name] as? JsonValue.Obj
internal fun JsonValue.Obj.string(name: String): String =
    (this[name] as? JsonValue.Str)?.value ?: throw IllegalStateException("game.store.${name}_missing")
internal fun JsonValue.Obj.stringOrNull(name: String): String? = when (val value = this[name]) {
    null, JsonValue.Null -> null
    is JsonValue.Str -> value.value
    else -> null
}
internal fun JsonValue.Obj.intOrDefault(name: String, default: Int): Int =
    (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: default
internal fun JsonValue.Obj.ulongOrDefault(name: String, default: ULong): ULong =
    when (val value = this[name]) {
        is JsonValue.Num -> value.raw.toULongOrNull() ?: default
        is JsonValue.Str -> value.value.toULongOrNull() ?: default
        else -> default
    }
internal fun JsonValue.Obj.boolOrDefault(name: String, default: Boolean): Boolean =
    (this[name] as? JsonValue.Bool)?.value ?: default
internal fun JsonValue.Obj.stringArray(name: String): List<String> =
    (this[name] as? JsonValue.Arr)?.values?.mapNotNull { (it as? JsonValue.Str)?.value } ?: emptyList()

internal fun JsonValue.Obj.withSettings(settings: GameSettingsState): JsonValue.Obj {
    val next = LinkedHashMap(entries)
    next["settings"] = JsonValue.Obj(linkedMapOf(
        "schemaVersion" to JsonValue.Num("1"),
        "autoReleaseEnabled" to JsonValue.Bool(settings.autoReleaseEnabled),
        "soundEnabled" to JsonValue.Bool(settings.soundEnabled),
        "musicEnabled" to JsonValue.Bool(settings.musicEnabled),
        "hapticsEnabled" to JsonValue.Bool(settings.hapticsEnabled),
        "notificationsEnabled" to JsonValue.Bool(settings.notificationsEnabled),
        "highContrastEnabled" to JsonValue.Bool(settings.highContrastEnabled),
        "reducedMotionEnabled" to JsonValue.Bool(settings.reducedMotionEnabled),
    ))
    return JsonValue.Obj(next)
}

internal fun JsonValue.Obj.withStage(stage: GameStage): JsonValue.Obj {
    val next = LinkedHashMap(entries)
    next["stage"] = JsonValue.Str(stage.wire)
    return JsonValue.Obj(next)
}

internal fun JsonValue.Obj.withHighSchool(highSchool: JsonValue.Obj?, stage: GameStage): JsonValue.Obj {
    val next = LinkedHashMap(entries)
    next["highSchool"] = highSchool ?: JsonValue.Null
    next["stage"] = JsonValue.Str(stage.wire)
    return JsonValue.Obj(next)
}

internal fun JsonValue.Obj.withPro(pro: JsonValue.Obj, stage: GameStage): JsonValue.Obj {
    val next = LinkedHashMap(entries)
    next["pro"] = pro
    next["stage"] = JsonValue.Str(stage.wire)
    return JsonValue.Obj(next)
}

internal fun JsonValue.Obj.withCommandReceipt(commandId: String): JsonValue.Obj {
    val next = LinkedHashMap(entries)
    val revision = ulongOrDefault("revision", 0UL) + 1UL
    next["revision"] = JsonValue.Num(revision.toString())
    val receipts = stringArray("commandReceipts").map(CareerWire::migrateCommandId).toMutableSet()
    receipts += CareerWire.migrateCommandId(commandId)
    next["commandReceipts"] = JsonValue.Arr(CommandReceiptRetention.retain(receipts.toList()).map(JsonValue::Str))
    return JsonValue.Obj(next)
}

internal fun JsonValue.Obj.toSettings(): GameSettingsState = GameSettingsState(
    autoReleaseEnabled = boolOrDefault("autoReleaseEnabled", false),
    soundEnabled = boolOrDefault("soundEnabled", true),
    musicEnabled = boolOrDefault("musicEnabled", true),
    hapticsEnabled = boolOrDefault("hapticsEnabled", true),
    notificationsEnabled = boolOrDefault("notificationsEnabled", false),
    highContrastEnabled = boolOrDefault("highContrastEnabled", false),
    reducedMotionEnabled = boolOrDefault("reducedMotionEnabled", false),
)

internal fun JsonValue.Obj.canonicalPlaceholder(): String = "legacy"
