package com.solkim.baseball.android

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent

internal object PolicyLinks {
    const val PRIVACY = "https://baseball-reincarnation.vercel.app/privacy"
    const val SUPPORT = "https://baseball-reincarnation.vercel.app/support"
    enum class Launch { CUSTOM_TAB, EXTERNAL, UNAVAILABLE }

    fun open(context: Context, url: String): Launch {
        require(url == PRIVACY || url == SUPPORT)
        val uri = Uri.parse(url)
        val provider = try {
            val candidates = context.packageManager.queryIntentServices(Intent("android.support.customtabs.action.CustomTabsService"), 0)
                .map { it.serviceInfo.packageName }.distinct()
            CustomTabsClient.getPackageName(context, candidates)
        }
        catch (error: Exception) { Log.w("PolicyLinks", "Provider lookup failed", error); null }
        return launchWithFallback(if (provider == null) null else ({
            val tab = CustomTabsIntent.Builder().setShowTitle(true).build()
            tab.intent.setPackage(provider)
            if (context !is Activity) tab.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            tab.launchUrl(context, uri)
        }), {
            val intent = Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
            if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        })
    }

    internal fun launchWithFallback(custom: (() -> Unit)?, external: () -> Unit): Launch {
        if (custom != null) try { custom(); return Launch.CUSTOM_TAB }
        catch (error: ActivityNotFoundException) { Log.w("PolicyLinks", "Custom Tab unavailable", error) }
        catch (error: SecurityException) { Log.w("PolicyLinks", "Custom Tab rejected", error) }
        return try { external(); Launch.EXTERNAL }
        catch (error: ActivityNotFoundException) { Log.w("PolicyLinks", "Browser unavailable", error); Launch.UNAVAILABLE }
        catch (error: SecurityException) { Log.w("PolicyLinks", "Browser rejected", error); Launch.UNAVAILABLE }
    }
}
