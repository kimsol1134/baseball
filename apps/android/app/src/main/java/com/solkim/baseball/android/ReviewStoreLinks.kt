package com.solkim.baseball.android

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri

/** Explicit review links use the store listing, where Play's in-app dialog quota cannot hide a tap. */
internal object ReviewStoreLinks {
    private const val APP_ID = "com.solkim.baseball.android"
    const val WEB_URL = "https://play.google.com/store/apps/details?id=$APP_ID"

    fun open(context: Context): Boolean {
        val intents = listOf(
            Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$APP_ID")).setPackage("com.android.vending"),
            Intent(Intent.ACTION_VIEW, Uri.parse(WEB_URL)),
        )
        for (intent in intents) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: ActivityNotFoundException) {
                // Devices without Play may still have a browser.
            } catch (_: SecurityException) {
                // A restricted store handler may still allow the public listing.
            }
        }
        return false
    }
}
