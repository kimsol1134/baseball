package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.util.Locale

public enum class GameLanguage(public val tag: String) {
    KOREAN("ko"), ENGLISH("en"), JAPANESE("ja");
    public companion object {
        public fun fromTag(tag: String): GameLanguage = entries.firstOrNull { it.tag == tag.substringBefore('-').substringBefore('_').lowercase(Locale.ROOT) } ?: ENGLISH
    }
}

public sealed interface GameCopyArgument {
    public data class UserText(val value: String) : GameCopyArgument
    public data class Whole(val value: Long) : GameCopyArgument
    public data class Decimal(val value: Double) : GameCopyArgument
    public data class Content(val key: String) : GameCopyArgument
}

/** Presentation-only catalogue; identifiers, player input, saves and RNG never pass through it. */
public class GameCopy(public val language: GameLanguage) {
    public fun resolve(key: String, vararg arguments: GameCopyArgument): String {
        val row = catalogue.entries[key] ?: error("copy.missing:$key")
        val template = row.getValue(language.tag)
        var sequential = 0
        return placeholder.replace(template) { match ->
            if (match.value == "%%") return@replace "%"
            val index = match.groupValues[1].removeSuffix("$").toIntOrNull()?.minus(1) ?: sequential++
            val argument = arguments.getOrNull(index) ?: error("copy.argument:$key:$index")
            when (val type = match.groupValues[3]) {
                "@", "s" -> when (argument) {
                    is GameCopyArgument.UserText -> argument.value
                    is GameCopyArgument.Content -> resolve(argument.key)
                    else -> error("copy.text_argument:$key:$index")
                }
                "d", "ld", "lld", "u", "lu", "llu" -> {
                    val value = (argument as? GameCopyArgument.Whole)?.value ?: error("copy.integer_argument:$key:$index")
                    if (match.value.contains(',')) java.text.NumberFormat.getIntegerInstance(Locale.forLanguageTag(language.tag)).format(value) else value.toString()
                }
                "f" -> {
                    val precision = match.groupValues[2].removePrefix(".").toIntOrNull() ?: 6
                    val value = (argument as? GameCopyArgument.Decimal)?.value ?: error("copy.decimal_argument:$key:$index")
                    String.format(Locale.forLanguageTag(language.tag), "%.${precision}f", value)
                }
                else -> error("copy.placeholder:$type")
            }
        }
    }

    /** A bounded compatibility index for the existing Kotlin/C# presentation strings.
     * New screens should use resolve(key, typed arguments). This never rewrites stored text.
     * Explicit user text is returned verbatim, even if it happens to equal a glossary term.
     */
    public fun legacy(text: String, userTexts: Set<String> = emptySet()): String {
        if (text.isBlank() || text in userTexts) return text
        if (text in catalogue.entries) return runCatching { resolve(text) }.getOrDefault(text)
        catalogue.sourceIndex[text]?.let {
            if (language != GameLanguage.KOREAN || it.startsWith("android.player.")) {
                return runCatching { resolve(it) }.getOrDefault(text)
            }
            return text
        }
        if (text.none { it in '\uAC00'..'\uD7A3' }) return text
        val cacheKey = "${language.tag}:${userTexts.hashCode()}:$text"
        synchronized(cache) { cache[cacheKey]?.let { return it } }
        val resolved = catalogue.patterns.firstNotNullOfOrNull { pattern ->
            if (language == GameLanguage.KOREAN && !pattern.key.startsWith("android.player.")) return@firstNotNullOfOrNull null
            if (pattern.anchor.isNotEmpty() && !text.contains(pattern.anchor)) return@firstNotNullOfOrNull null
            val match = pattern.regex.matchEntire(text) ?: return@firstNotNullOfOrNull null
            val arguments = arrayOfNulls<GameCopyArgument>(pattern.argumentCount)
            pattern.arguments.forEachIndexed { index, descriptor ->
                val raw = match.groupValues[index + 1]
                val arg = when (descriptor.type) {
                    "@", "s" -> GameCopyArgument.UserText(legacy(raw, userTexts))
                    "f" -> raw.replace(",", "").toDoubleOrNull()?.let(GameCopyArgument::Decimal)
                    else -> raw.replace(",", "").toLongOrNull()?.let(GameCopyArgument::Whole)
                } ?: return@firstNotNullOfOrNull null
                if (arguments[descriptor.index] != null && arguments[descriptor.index] != arg) return@firstNotNullOfOrNull null
                arguments[descriptor.index] = arg
            }
            if (arguments.any { it == null }) null else runCatching { resolve(pattern.key, *arguments.filterNotNull().toTypedArray()) }.getOrNull()
        } ?: listOf(" · ", "\n").firstOrNull { text.contains(it) }?.let { separator ->
            text.split(separator).joinToString(separator) { legacy(it, userTexts) }
        } ?: text
        synchronized(cache) { cache[cacheKey] = resolved }
        return resolved
    }

    /** Core recommendations compose complete sentences from separate, translated reasons. */
    public fun sentences(text: String): String = text.split(Regex("(?<=\\.)\\s+"))
        .joinToString(" ") { legacy(it) }

    public fun hasKey(key: String): Boolean = key in catalogue.entries

    public companion object {
        private val placeholder = Regex("%%|%(\\d+\\$)?(?:[-+0-9,]*)(\\.\\d+)?(lld|llu|ld|lu|@|s|d|u|f)")
        private val numericSuffix = Regex("^(?:번째|경기|구(?=[\\s·,.!]|$)|탈삼진|볼넷|실점|아웃|이닝|시즌|주차|년|세|승|패|점|회|위|원|%)")
        private val cache = object : LinkedHashMap<String, String>(256, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?): Boolean = size > 2048
        }
        private data class Argument(val index: Int, val type: String)
        private data class Pattern(val key: String, val regex: Regex, val anchor: String, val arguments: List<Argument>, val argumentCount: Int)
        private data class Catalogue(val entries: Map<String, Map<String, String>>, val sourceIndex: Map<String, String>, val patterns: List<Pattern>)
        private val catalogue: Catalogue by lazy {
            val bytes = checkNotNull(GameCopy::class.java.classLoader?.getResourceAsStream("localization/game-copy.json")) { "copy.catalogue_missing" }.use { it.readBytes() }
            val root = StrictJson.parseUtf8(bytes) as JsonValue.Obj
            val entries = (root.entries.getValue("entries") as JsonValue.Obj).entries.mapValues { (_, row) ->
                (row as JsonValue.Obj).entries.mapValues { (_, value) -> (value as JsonValue.Str).value }
            }
            val index = (root.entries.getValue("legacySourceIndex") as JsonValue.Obj).entries.mapValues { (_, value) -> (value as JsonValue.Str).value }
            val patterns = index.mapNotNull { (source, key) ->
                val matches = placeholder.findAll(source).filter { it.value != "%%" }.toList()
                if (matches.isEmpty()) return@mapNotNull null
                var cursor = 0
                var sequential = 0
                val arguments = mutableListOf<Argument>()
                val literalPieces = mutableListOf<String>()
                val regex = buildString {
                    for (match in matches) {
                        val literal = source.substring(cursor, match.range.first).replace("%%", "%")
                        literalPieces += literal
                        append(Regex.escape(literal))
                        val type = match.groupValues[3]
                        val isText = (type == "@" || type == "s") && !numericSuffix.containsMatchIn(source.substring(match.range.last + 1))
                        append(if (isText) "(.*?)" else "([-+0-9,.]+)")
                        val position = match.groupValues[1].removeSuffix("$").toIntOrNull()?.minus(1) ?: sequential++
                        arguments += Argument(position, type)
                        cursor = match.range.last + 1
                    }
                    val literal = source.substring(cursor).replace("%%", "%")
                    literalPieces += literal
                    append(Regex.escape(literal))
                }
                val anchor = literalPieces.maxByOrNull { it.length }.orEmpty()
                if (anchor.none { it in '\uAC00'..'\uD7A3' }) return@mapNotNull null
                Pattern(key, Regex(regex), anchor, arguments, arguments.maxOf { it.index } + 1)
            }.sortedWith(compareByDescending<Pattern> { it.key.startsWith("android.player.") }.thenByDescending { it.anchor.length })
            Catalogue(entries, index, patterns)
        }
    }
}
