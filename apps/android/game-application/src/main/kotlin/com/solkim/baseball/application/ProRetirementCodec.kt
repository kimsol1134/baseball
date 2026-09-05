package com.solkim.baseball.application

import com.solkim.baseball.core.pro.ProState
import com.solkim.baseball.core.pro.ProStateCodec
import com.solkim.baseball.model.JsonValue
import java.util.Base64

/** Optional extension shared by native saves and the legacy import envelope. */
internal object ProRetirementCodec {
    fun balance(value: JsonValue?): Int {
        if (value == null) return 0
        require(value is JsonValue.Num) { "retirement.balance_number" }
        return value.raw.toInt().also { require(it >= 0) { "retirement.balance_negative" } }
    }
    fun encode(careers: List<ProState>): JsonValue.Arr = JsonValue.Arr(careers.map {
        JsonValue.Str(Base64.getUrlEncoder().withoutPadding().encodeToString(ProStateCodec.encode(it)))
    })
    fun decode(value: JsonValue?): List<ProState> {
        if (value == null) return emptyList()
        require(value is JsonValue.Arr) { "retirement.archive_array" }
        return value.values.map {
            require(it is JsonValue.Str) { "retirement.archive_string" }
            val bytes = Base64.getUrlDecoder().decode(it.value)
            require(Base64.getUrlEncoder().withoutPadding().encodeToString(bytes) == it.value) { "retirement.archive_canonical" }
            ProStateCodec.decode(bytes)
        }
    }
}
