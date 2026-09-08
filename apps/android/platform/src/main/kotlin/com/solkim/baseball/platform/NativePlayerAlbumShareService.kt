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
    val stats: List<Pair<String, String>>, val caption: String, val appName: String,
    val line: List<Pair<String, String>> = emptyList(), val rates: List<Pair<String, String>> = emptyList())

/** The same pixels are previewed, saved and explicitly shared. No career mutation or network posting. */
public class NativePlayerAlbumShareService(private val context: Context) {
    public fun render(card: AlbumShareCard, portrait: Bitmap?): Bitmap {
        val bitmap = Bitmap.createBitmap(1080, 1350, Bitmap.Config.ARGB_8888)
        val c = Canvas(bitmap)
        val paper = Color.rgb(244, 242, 235)
        val navy = Color.rgb(14, 24, 38)
        val blue = Color.rgb(37, 83, 238)
        val muted = Color.rgb(101, 111, 122)
        c.drawColor(paper)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        fun rect(l: Float, t: Float, r: Float, b: Float, color: Int) {
            paint.shader = null; paint.color = color; c.drawRect(l, t, r, b, paint)
        }
        fun text(value: String, x: Float, y: Float, width: Int, height: Int, size: Float, color: Int,
                 bold: Boolean = false, mono: Boolean = false) {
            val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color; textSize = size
                typeface = Typeface.create(if (mono) "monospace" else "sans-serif", if (bold) Typeface.BOLD else Typeface.NORMAL)
            }
            fun layout() = StaticLayout.Builder.obtain(value, 0, value.length, tp, width)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(false).build()
            var l = layout()
            while (l.height > height && tp.textSize > 18f) { tp.textSize -= 2; l = layout() }
            c.save(); c.translate(x, y); l.draw(c); c.restore()
        }
        // Full-bleed portrait and a compact editorial nameplate, with no decorative card-in-card.
        rect(0f, 0f, 1080f, 580f, navy)
        if (portrait != null) {
            val dst = RectF(500f, 0f, 1080f, 580f)
            val scale = maxOf(dst.width()/portrait.width, dst.height()/portrait.height)
            val sw = dst.width()/scale; val sh = dst.height()/scale
            val src = Rect(((portrait.width-sw)/2).toInt(), 0, ((portrait.width+sw)/2).toInt(), sh.toInt().coerceAtMost(portrait.height))
            c.drawBitmap(portrait, src, dst, Paint(Paint.FILTER_BITMAP_FLAG))
            paint.shader = LinearGradient(430f, 0f, 860f, 0f, intArrayOf(navy, Color.TRANSPARENT), null, Shader.TileMode.CLAMP)
            c.drawRect(430f, 0f, 1080f, 580f, paint)
            paint.shader = LinearGradient(0f, 400f, 0f, 580f, intArrayOf(Color.TRANSPARENT, navy), null, Shader.TileMode.CLAMP)
            c.drawRect(0f, 400f, 1080f, 580f, paint); paint.shader = null
        }
        rect(56f, 55f, 64f, 91f, blue)
        text(card.title, 82f, 56f, 570, 50, 30f, Color.rgb(198, 210, 229), true)
        text(card.name, 56f, 155f, 615, 218, 106f, Color.WHITE, true)
        text(card.subtitle, 60f, 398f, 830, 88, 31f, Color.rgb(211, 220, 233))
        text(card.caption.replace("\n", " · "), 60f, 510f, 960, 45, 25f, Color.rgb(168, 187, 209))
        val values = card.line.toMap()
        val hero = if (card.rates.isNotEmpty()) listOf("WHIP" to (card.rates.toMap()["WHIP"] ?: "—"), "IP" to (values["IP"] ?: "—"), "SO" to (values["SO"] ?: "—")) else card.stats.take(3)
        hero.forEachIndexed { i, (label, value) ->
            val x = 58f + i * 336f
            text(label, x, 625f, 305, 38, 29f, muted, true)
            text(value, x-3, 678f, 306, 121, if (i==0) 107f else 94f, if (i==0) blue else navy, true, true)
        }
        rect(58f, 825f, 1022f, 827f, navy)
        card.line.take(12).chunked(6).forEachIndexed { row, cells ->
            cells.forEachIndexed { col, (label, value) ->
                val x = 60f + col*164f; val y = 856f + row*108f
                text(label, x, y, 150, 33, 25f, muted, true)
                text(value, x, y+39, 150, 53, 39f, navy, true, true)
            }
        }
        rect(58f, 1082f, 1022f, 1084f, Color.rgb(199, 201, 200))
        card.rates.filter { it.first != "WHIP" }.take(5).forEachIndexed { i, (label, value) ->
            val x = 60f + i*197f
            text(label, x, 1113f, 180, 35, 25f, muted, true)
            text(value, x, 1153f, 180, 65, 40f, navy, true, true)
        }
        rect(0f, 1260f, 1080f, 1350f, navy)
        text(card.appName, 60f, 1288f, 950, 40, 26f, Color.rgb(200, 210, 226))
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
