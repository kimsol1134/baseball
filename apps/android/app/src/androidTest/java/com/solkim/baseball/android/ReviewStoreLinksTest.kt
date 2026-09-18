package com.solkim.baseball.android

import android.content.ActivityNotFoundException
import android.content.ContextWrapper
import android.content.Intent
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test

class ReviewStoreLinksTest {
    @Test fun explicitReviewOpensProductionListingWithBrowserFallback() {
        val base = InstrumentationRegistry.getInstrumentation().targetContext
        for (failures in 0..2) {
            val captured = mutableListOf<Intent>()
            val context = object : ContextWrapper(base) {
                override fun startActivity(intent: Intent) {
                    captured += intent
                    if (captured.size <= failures) throw ActivityNotFoundException("test handler unavailable")
                }
            }
            assertEquals(failures < 2, ReviewStoreLinks.open(context))
            assertEquals("com.android.vending", captured.first().`package`)
            assertEquals("market://details?id=com.solkim.baseball.android", captured.first().dataString)
            if (failures > 0) assertEquals("https://play.google.com/store/apps/details?id=com.solkim.baseball.android", captured.last().dataString)
            assertTrue(captured.all { it.action == Intent.ACTION_VIEW })
        }
    }
}
