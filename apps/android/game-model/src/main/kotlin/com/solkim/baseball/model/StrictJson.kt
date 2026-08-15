package com.solkim.baseball.model

import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/**
 * Small, dependency-free JSON tree used at the migration boundaries.
 *
 * It deliberately rejects duplicate keys, comments, trailing content, malformed UTF-8,
 * non-JSON numbers, and nesting deeper than the save/bridge contract allows. Kotlin
 * serialization can be introduced after the wire is frozen; this parser keeps the first pass
 * independent of generated serializers and lets additive fields survive a decode/re-encode.
 */
public sealed interface JsonValue {
    public data class Obj(public val entries: LinkedHashMap<String, JsonValue>) : JsonValue {
        public operator fun get(key: String): JsonValue? = entries[key]
    }

    public data class Arr(public val values: List<JsonValue>) : JsonValue
    public data class Str(public val value: String) : JsonValue
    public data class Num(public val raw: String) : JsonValue
    public data class Bool(public val value: Boolean) : JsonValue
    public data object Null : JsonValue
}

public class StrictJsonException(message: String) : IllegalArgumentException(message)

public object StrictJson {
    public const val DEFAULT_MAX_DEPTH: Int = 128

    public fun parseUtf8(bytes: ByteArray, maxDepth: Int = DEFAULT_MAX_DEPTH): JsonValue {
        val decoder = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        val text = try {
            decoder.decode(ByteBuffer.wrap(bytes)).toString()
        } catch (error: Exception) {
            throw StrictJsonException("json.utf8_invalid:${error.javaClass.simpleName}")
        }
        return Parser(text, maxDepth).parseDocument()
    }

    public fun parse(text: String, maxDepth: Int = DEFAULT_MAX_DEPTH): JsonValue =
        Parser(text, maxDepth).parseDocument()

    public fun compact(value: JsonValue, sortKeys: Boolean = false): String =
        Renderer(sortKeys = sortKeys).render(value)

    public fun canonical(value: JsonValue): String = compact(value, sortKeys = true)

    private class Parser(
        private val source: String,
        private val maxDepth: Int,
    ) {
        private var index: Int = 0

        fun parseDocument(): JsonValue {
            skipWhitespace()
            val value = parseValue(0)
            skipWhitespace()
            if (index != source.length) fail("json.trailing_content")
            return value
        }

        private fun parseValue(depth: Int): JsonValue {
            if (depth > maxDepth) fail("json.max_depth")
            if (index >= source.length) fail("json.unexpected_eof")
            return when (source[index]) {
                '{' -> parseObject(depth + 1)
                '[' -> parseArray(depth + 1)
                '"' -> JsonValue.Str(parseString())
                't' -> parseLiteral("true", JsonValue.Bool(true))
                'f' -> parseLiteral("false", JsonValue.Bool(false))
                'n' -> parseLiteral("null", JsonValue.Null)
                '-', in '0'..'9' -> JsonValue.Num(parseNumber())
                else -> fail("json.unexpected_token:${source[index]}")
            }
        }

        private fun parseObject(depth: Int): JsonValue.Obj {
            expect('{')
            skipWhitespace()
            val entries = LinkedHashMap<String, JsonValue>()
            if (consumeIf('}')) return JsonValue.Obj(entries)
            while (true) {
                if (peek() != '"') fail("json.object_key_required")
                val key = parseString()
                if (entries.containsKey(key)) fail("json.duplicate_key:$key")
                skipWhitespace()
                expect(':')
                skipWhitespace()
                entries[key] = parseValue(depth)
                skipWhitespace()
                when {
                    consumeIf('}') -> return JsonValue.Obj(entries)
                    consumeIf(',') -> {
                        skipWhitespace()
                        if (peek() == '}') fail("json.trailing_comma")
                    }
                    else -> fail("json.object_separator_required")
                }
            }
        }

        private fun parseArray(depth: Int): JsonValue.Arr {
            expect('[')
            skipWhitespace()
            val values = ArrayList<JsonValue>()
            if (consumeIf(']')) return JsonValue.Arr(values)
            while (true) {
                values += parseValue(depth)
                skipWhitespace()
                when {
                    consumeIf(']') -> return JsonValue.Arr(values)
                    consumeIf(',') -> {
                        skipWhitespace()
                        if (peek() == ']') fail("json.trailing_comma")
                    }
                    else -> fail("json.array_separator_required")
                }
            }
        }

        private fun parseLiteral(literal: String, value: JsonValue): JsonValue {
            if (!source.regionMatches(index, literal, 0, literal.length)) {
                fail("json.invalid_literal")
            }
            index += literal.length
            return value
        }

        private fun parseString(): String {
            expect('"')
            val output = StringBuilder()
            while (index < source.length) {
                val character = source[index++]
                when {
                    character == '"' -> return output.toString()
                    character.code < 0x20 -> fail("json.control_character_in_string")
                    character != '\\' -> output.append(character)
                    index >= source.length -> fail("json.string_escape_eof")
                    else -> when (val escaped = source[index++]) {
                        '"', '\\', '/' -> output.append(escaped)
                        'b' -> output.append('\b')
                        'f' -> output.append('\u000C')
                        'n' -> output.append('\n')
                        'r' -> output.append('\r')
                        't' -> output.append('\t')
                        'u' -> output.append(parseUnicodeEscape())
                        else -> fail("json.invalid_escape:$escaped")
                    }
                }
            }
            fail("json.unterminated_string")
        }

        private fun parseUnicodeEscape(): Char {
            if (index + 4 > source.length) fail("json.unicode_escape_eof")
            var value = 0
            repeat(4) {
                val digit = source[index++].digitToIntOrNull(16)
                    ?: fail("json.invalid_unicode_escape")
                value = (value shl 4) or digit
            }
            return value.toChar()
        }

        private fun parseNumber(): String {
            val start = index
            if (consumeIf('-') && index >= source.length) fail("json.number_eof")
            when {
                consumeIf('0') -> if (peek()?.isDigit() == true) fail("json.leading_zero")
                peek()?.let { it in '1'..'9' } == true -> while (peek()?.isDigit() == true) index++
                else -> fail("json.invalid_number")
            }
            if (consumeIf('.')) {
                if (peek()?.isDigit() != true) fail("json.fraction_digit_required")
                while (peek()?.isDigit() == true) index++
            }
            if (peek() == 'e' || peek() == 'E') {
                index++
                if (peek() == '+' || peek() == '-') index++
                if (peek()?.isDigit() != true) fail("json.exponent_digit_required")
                while (peek()?.isDigit() == true) index++
            }
            return source.substring(start, index)
        }

        private fun skipWhitespace() {
            while (index < source.length) {
                when (source[index]) {
                    ' ', '\n', '\r', '\t' -> index++
                    else -> return
                }
            }
        }

        private fun expect(expected: Char) {
            if (!consumeIf(expected)) fail("json.expected:$expected")
        }

        private fun consumeIf(expected: Char): Boolean {
            if (index < source.length && source[index] == expected) {
                index++
                return true
            }
            return false
        }

        private fun peek(): Char? = source.getOrNull(index)

        private fun fail(code: String): Nothing =
            throw StrictJsonException("$code@$index")
    }

    private class Renderer(private val sortKeys: Boolean) {
        fun render(value: JsonValue): String = buildString { appendValue(value) }

        private fun StringBuilder.appendValue(value: JsonValue) {
            when (value) {
                is JsonValue.Obj -> {
                    append('{')
                    val entries = if (sortKeys) {
                        value.entries.entries.sortedBy { it.key }
                    } else {
                        value.entries.entries.toList()
                    }
                    entries.forEachIndexed { position, (key, child) ->
                        if (position > 0) append(',')
                        appendString(key)
                        append(':')
                        appendValue(child)
                    }
                    append('}')
                }
                is JsonValue.Arr -> {
                    append('[')
                    value.values.forEachIndexed { position, child ->
                        if (position > 0) append(',')
                        appendValue(child)
                    }
                    append(']')
                }
                is JsonValue.Str -> appendString(value.value)
                is JsonValue.Num -> append(value.raw)
                is JsonValue.Bool -> append(if (value.value) "true" else "false")
                JsonValue.Null -> append("null")
            }
        }

        private fun StringBuilder.appendString(value: String) {
            append('"')
            value.forEach { character ->
                when (character) {
                    '"' -> append("\\\"")
                    '\\' -> append("\\\\")
                    '\b' -> append("\\b")
                    '\u000C' -> append("\\f")
                    '\n' -> append("\\n")
                    '\r' -> append("\\r")
                    '\t' -> append("\\t")
                    in '\u0000'..'\u001F' -> append("\\u%04x".format(character.code))
                    else -> append(character)
                }
            }
            append('"')
        }
    }
}
