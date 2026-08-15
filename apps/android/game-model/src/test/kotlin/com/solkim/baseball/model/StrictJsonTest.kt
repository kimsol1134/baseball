package com.solkim.baseball.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class StrictJsonTest {
    @Test
    fun canonicalObjectOrderIsOrdinalAndArraysKeepOrder() {
        val value = StrictJson.parse("{\"z\":[2,1],\"a\":{\"b\":true,\"a\":null}}")
        assertEquals("{\"a\":{\"a\":null,\"b\":true},\"z\":[2,1]}", StrictJson.canonical(value))
    }

    @Test
    fun duplicateAndTrailingContentAreRejected() {
        assertFailsWith<StrictJsonException> { StrictJson.parse("{\"a\":1,\"a\":2}") }
        assertFailsWith<StrictJsonException> { StrictJson.parse("{\"a\":1} false") }
        assertFailsWith<StrictJsonException> { StrictJson.parse("[1,]") }
    }

    @Test
    fun fnvAndShaHelpersHaveStableWireValues() {
        assertEquals("cbf29ce484222325", Hashing.fnv1a64Hex(""))
        assertEquals("af63dc4c8601ec8c", Hashing.fnv1a64Hex("a"))
        assertEquals("e43442a27180caf1", Hashing.fnv1a64Hex("야구"))
    }
}
