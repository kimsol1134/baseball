package com.solkim.baseball.platform

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import androidx.core.content.FileProvider
import com.solkim.baseball.model.Hashing
import java.io.File

/** An achievement the player explicitly chose to share; no automatic publishing. */
public class NativeAchievementShareService(private val context: Context) {
    public fun share(title: String, text: String, appName: String, installUrl: String, challengeUrl: String? = null): ShareResult {
        val body = listOfNotNull(text, appName, challengeUrl, installUrl).joinToString("\n\n")
        val fallback = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, title)
            putExtra(Intent.EXTRA_TEXT, body)
        }
        return try {
            val folder = File(context.cacheDir, "achievement-share").apply { mkdirs() }
            val imageFile = File(folder, "${Hashing.sha256Hex("$title|$text|$appName").take(24)}.png")
            val bitmap = render(title, text, appName)
            try {
                imageFile.outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            } finally { bitmap.recycle() }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.baseball.share", imageFile)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_SUBJECT, title)
                putExtra(Intent.EXTRA_TEXT, body)
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = ClipData.newRawUri(title, uri)
            }
            context.startActivity(Intent.createChooser(intent, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            ShareResult.ChooserOpened
        } catch (_: Exception) {
            runCatching { context.startActivity(Intent.createChooser(fallback, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                .fold({ ShareResult.TextFallbackChooserOpened }, { ShareResult.Failed("share.achievement") })
        }
    }

    internal fun render(title: String, text: String, appName: String): Bitmap {
        val bitmap = Bitmap.createBitmap(1080, 1350, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawColor(Color.rgb(8, 13, 11))
        paint.color = Color.rgb(16, 24, 21)
        canvas.drawRoundRect(RectF(48f, 48f, 1032f, 1302f), 36f, 36f, paint)
        paint.color = Color.rgb(183, 243, 107)
        canvas.drawRoundRect(RectF(90f, 110f, 194f, 122f), 6f, 6f, paint)
        fun paragraph(value: String, top: Float, maxHeight: Int, initialSize: Float, color: Int, bold: Boolean) {
            val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color
                typeface = Typeface.create(Typeface.SANS_SERIF, if (bold) Typeface.BOLD else Typeface.NORMAL)
            }
            var size = initialSize
            fun layout(): StaticLayout {
                textPaint.textSize = size
                return StaticLayout.Builder.obtain(value, 0, value.length, textPaint, 900)
                    .setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(true).setLineSpacing(8f, 1.05f).build()
            }
            var block = layout()
            while (block.height > maxHeight && size > 24f) { size -= 2f; block = layout() }
            if (block.height > maxHeight) {
                var maxLines = block.lineCount
                do {
                    maxLines = (maxLines - 1).coerceAtLeast(1)
                    block = StaticLayout.Builder.obtain(value, 0, value.length, textPaint, 900)
                        .setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(true)
                        .setLineSpacing(8f, 1.05f).setMaxLines(maxLines)
                        .setEllipsize(TextUtils.TruncateAt.END).build()
                } while (block.height > maxHeight && maxLines > 1)
            }
            canvas.save()
            canvas.translate(90f, top)
            block.draw(canvas)
            canvas.restore()
        }
        paragraph(title, 164f, 230, 82f, Color.rgb(216, 181, 101), true)
        paragraph(text, 440f, 610, 52f, Color.rgb(241, 244, 238), false)
        paint.color = Color.rgb(63, 85, 75)
        canvas.drawLine(90f, 1132f, 990f, 1132f, paint)
        paragraph(appName, 1170f, 100, 38f, Color.rgb(183, 243, 107), true)
        return bitmap
    }
}
