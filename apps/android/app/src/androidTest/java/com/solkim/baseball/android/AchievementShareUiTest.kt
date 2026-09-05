package com.solkim.baseball.android

import android.content.ContextWrapper
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.solkim.baseball.application.GameCopy
import com.solkim.baseball.application.GameLanguage
import com.solkim.baseball.platform.NativeAchievementShareService
import com.solkim.baseball.platform.ShareResult
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Inspect the real PNG and share grants without sending anything to another app. */
@RunWith(AndroidJUnit4::class)
class AchievementShareUiTest {
    @Test fun localizedCardsExposeReadablePngAndTextThroughTheChooser() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        require(context.packageName.endsWith(".compose.qa"))
        var chooser: Intent? = null
        val capture = object : ContextWrapper(context) {
            override fun startActivity(intent: Intent) { chooser = intent }
        }
        for (language in GameLanguage.entries) {
            val copy = GameCopy(language)
            val tag = when (language) { GameLanguage.KOREAN -> "ko"; GameLanguage.ENGLISH -> "en"; GameLanguage.JAPANESE -> "ja" }
            val name = when (language) { GameLanguage.KOREAN -> "민서준"; GameLanguage.ENGLISH -> "Min Seo-jun"; GameLanguage.JAPANESE -> "ミン・ソジュン" }
            val title = copy.legacy("프로에서 남긴 유산")
            val body = name + "\n" + copy.legacy("통산 20시즌 · 500경기 · 2300탈삼진") + "\n" + copy.legacy("흔들리지 않는 릴리스")
            val link = "https://baseball-reincarnation.vercel.app/challenge/123-1"
            assertEquals(ShareResult.ChooserOpened, NativeAchievementShareService(capture).share(title, body,
                copy.resolve("android.app.name"), "https://play.google.com/store/apps/details?id=com.solkim.baseball.android", link))
            assertEquals(Intent.ACTION_CHOOSER, chooser?.action)
            @Suppress("DEPRECATION")
            val send = requireNotNull(chooser?.getParcelableExtra<Intent>(Intent.EXTRA_INTENT))
            assertEquals("image/png", send.type)
            assertTrue(send.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
            assertTrue(requireNotNull(send.getStringExtra(Intent.EXTRA_TEXT)).contains(link))
            assertTrue(requireNotNull(send.getStringExtra(Intent.EXTRA_TEXT)).contains(body))
            @Suppress("DEPRECATION")
            val uri = requireNotNull(send.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            assertEquals("content", uri.scheme)
            assertEquals(uri, send.clipData?.getItemAt(0)?.uri)
            val bytes = context.contentResolver.openInputStream(uri)!!.use { it.readBytes() }
            val bitmap = requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size))
            assertEquals(1080, bitmap.width)
            assertEquals(1350, bitmap.height)
            bitmap.recycle()
            File(context.cacheDir, "qa-share-$tag.png").writeBytes(bytes)
        }
    }
}
