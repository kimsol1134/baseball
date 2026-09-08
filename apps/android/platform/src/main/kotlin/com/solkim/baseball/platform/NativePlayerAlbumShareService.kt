package com.solkim.baseball.platform

import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.provider.MediaStore
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.core.content.FileProvider
import java.io.File

public data class AlbumShareCard(val title: String, val name: String, val subtitle: String,
    val stats: List<Pair<String, String>>, val caption: String, val appName: String)

/** The same pixels are previewed, saved and explicitly shared. No career mutation or network posting. */
public class NativePlayerAlbumShareService(private val context: Context) {
    public fun render(card: AlbumShareCard, portrait: Bitmap?): Bitmap {
        val bitmap = Bitmap.createBitmap(1080, 1350, Bitmap.Config.ARGB_8888)
        val c = Canvas(bitmap); c.drawColor(Color.rgb(11, 15, 13))
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(23, 32, 27) }
        c.drawRoundRect(RectF(40f, 40f, 1040f, 1310f), 36f, 36f, p)
        fun text(value: String, x: Float, y: Float, width: Int, height: Int, size: Float, color: Int, bold: Boolean = false) {
            val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color; textSize = size; typeface = Typeface.create("sans-serif", if (bold) Typeface.BOLD else Typeface.NORMAL) }
            fun layout() = StaticLayout.Builder.obtain(value, 0, value.length, tp, width).setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(false).build()
            var l = layout()
            while (l.height > height && tp.textSize > 20f) { tp.textSize -= 2; l = layout() }
            c.save(); c.translate(x, y); l.draw(c); c.restore()
        }
        val ink = Color.rgb(240, 244, 240); val green = Color.rgb(196, 255, 92); val muted = Color.rgb(170, 184, 175)
        text(card.title, 90f, 95f, 900, 190, 70f, green, true)
        if (portrait != null) c.drawBitmap(portrait, null, RectF(90f, 320f, 320f, 600f), Paint(Paint.FILTER_BITMAP_FLAG))
        val left = if (portrait == null) 90f else 360f
        text(card.name, left, 340f, (990-left).toInt(), 170, 76f, ink, true)
        text(card.subtitle, left, 520f, (990-left).toInt(), 110, 34f, muted)
        card.stats.take(3).forEachIndexed { i, (label, value) ->
            text(value, 90f + i*300, 720f, 280, 110, 80f, green, true)
            text(label, 90f + i*300, 830f, 280, 90, 34f, muted)
        }
        text(card.caption, 90f, 980f, 900, 190, 40f, ink)
        text(card.appName, 90f, 1230f, 900, 60, 30f, muted)
        return bitmap
    }
    public fun share(bitmap: Bitmap, title: String): ShareResult = try {
        val folder = File(context.cacheDir, "achievement-share").apply { mkdirs() }
        val file = File(folder, "player-album-${System.nanoTime()}.png")
        file.outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.baseball.share", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"; putExtra(Intent.EXTRA_STREAM, uri); putExtra(Intent.EXTRA_SUBJECT, title)
            clipData = ClipData.newRawUri(title, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        ShareResult.ChooserOpened
    } catch (_: Exception) { ShareResult.Failed("album.share") }
    public fun save(bitmap: Bitmap): Boolean {
        if (Build.VERSION.SDK_INT < 29) return false
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "pitcher-${System.currentTimeMillis()}.png")
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/MoundReborn")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = try { resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) } catch (_: Exception) { null } ?: return false
        return try {
            resolver.openOutputStream(uri).use { stream -> check(stream != null && bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) }
            resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
            true
        } catch (_: Exception) { resolver.delete(uri, null, null); false }
    }
}
