package com.example.wisata_daerahku

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.SystemClock
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/** Scoped FileProvider for the temporary payment QR image; see res/xml/payment_qr_paths.xml. */
class PaymentQrFileProvider : FileProvider()

class MainActivity : FlutterActivity() {
    private class PendingSave(val bytes: ByteArray, val result: MethodChannel.Result, val cutoff: Long)

    private var pendingSave: PendingSave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.wisatadaerahku.app/payment_qr")
            .setMethodCallHandler { call, result ->
                val validFor = call.argument<Number>("validForMillis")?.toLong() ?: 0L
                if (validFor <= 0) {
                    result.success("expired")
                    return@setMethodCallHandler
                }
                val cutoff = SystemClock.elapsedRealtime() + validFor.coerceAtMost(15 * 60 * 1000L)
                when (call.method) {
                    "saveImage" -> saveQrImage(call.argument<ByteArray>("bytes"), call.argument<String>("fileName"),
                        call.argument<String>("mimeType"), result, cutoff)
                    "shareImage" -> shareQrImage(call.argument<ByteArray>("bytes"), call.argument<String>("fileName"),
                        call.argument<String>("mimeType"), result, cutoff)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.wisatadaerahku.app/maps")
            .setMethodCallHandler { call, result ->
                if (call.method != "openDirections") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val latitude = (call.argument<Any>("latitude") as? Number)?.toDouble()
                val longitude = (call.argument<Any>("longitude") as? Number)?.toDouble()
                if (latitude == null || longitude == null ||
                    !latitude.isFinite() || !longitude.isFinite() ||
                    latitude !in -90.0..90.0 || longitude !in -180.0..180.0) {
                    result.error("INVALID_COORDINATES", "Lokasi destinasi belum tersedia", null)
                    return@setMethodCallHandler
                }
                val uri = Uri.Builder().scheme("https").authority("www.google.com")
                    .path("/maps/dir/").appendQueryParameter("api", "1")
                    .appendQueryParameter("destination", "$latitude,$longitude").build()
                if (tryOpen(Intent(Intent.ACTION_VIEW, uri)
                        .setPackage("com.google.android.apps.maps"))) {
                    result.success("maps")
                    return@setMethodCallHandler
                }
                // Resolve a generic URL so Maps link preferences cannot hide browsers.
                val webIntent = Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
                val browserProbe = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.org"))
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                val browsers = packageManager.queryIntentActivities(browserProbe, PackageManager.MATCH_DEFAULT_ONLY)
                    .map { it.activityInfo.packageName }.distinct()
                    .filter { it != "com.google.android.apps.maps" }
                val defaultBrowser = packageManager.resolveActivity(browserProbe,
                    PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
                val opened = browsers.sortedBy { it != defaultBrowser }
                    .any { tryOpen(Intent(webIntent).setPackage(it)) }
                result.success(if (opened) "browser" else "unavailable")
            }
    }

    /** A PNG that is small, correctly typed and has a harmless file name; anything else is rejected. */
    private fun validQrImage(bytes: ByteArray?, fileName: String?, mimeType: String?): String? {
        if (bytes == null || bytes.isEmpty() || bytes.size > MAX_QR_BYTES || mimeType != "image/png") return null
        val base = (fileName ?: "qris-pembayaran.png").replace(Regex("[^A-Za-z0-9._-]"), "_").take(80)
        return if (base.endsWith(".png")) base else "$base.png"
    }

    /**
     * Save through the system "create document" picker: the customer chooses the place, so no storage
     * permission is needed. The bytes live in memory only until the picker answers.
     */
    private fun saveQrImage(bytes: ByteArray?, fileName: String?, mimeType: String?, result: MethodChannel.Result, cutoff: Long) {
        val name = validQrImage(bytes, fileName, mimeType)
        if (name == null || bytes == null) {
            result.error("INVALID_IMAGE", "Gambar QR tidak valid", null)
            return
        }
        if (pendingSave != null) {
            result.error("BUSY", "Penyimpanan QR sedang berjalan", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("image/png")
            .putExtra(Intent.EXTRA_TITLE, name)
        pendingSave = PendingSave(bytes, result, cutoff)
        try {
            startActivityForResult(intent, SAVE_QR_REQUEST)
        } catch (error: ActivityNotFoundException) {
            pendingSave = null
            result.error("UNAVAILABLE", "Tidak ada aplikasi penyimpanan", null)
        } catch (error: SecurityException) {
            pendingSave = null
            result.error("PERMISSION_DENIED", "Akses penyimpanan ditolak", null)
        }
    }

    @Deprecated("Needed for the Storage Access Framework save result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_QR_REQUEST) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val pending = pendingSave ?: return
        pendingSave = null
        val target = data?.data
        if (resultCode != Activity.RESULT_OK || target == null) {
            pending.result.success("cancelled")
            return
        }
        if (SystemClock.elapsedRealtime() >= pending.cutoff) {
            pending.result.success("expired")
            return
        }
        try {
            val stream = contentResolver.openOutputStream(target, "wt") ?: throw IOException("No stream")
            stream.use { it.write(pending.bytes) }
            pending.result.success("saved")
        } catch (error: SecurityException) {
            pending.result.error("PERMISSION_DENIED", "Akses penyimpanan ditolak", null)
        } catch (error: IOException) {
            Log.w("PaymentQrExport", "Save failed: ${error.javaClass.simpleName}")
            pending.result.error("IO_ERROR", "QR gagal disimpan", null)
        }
    }

    /**
     * Share through a chooser with a read-only content URI from a cache sub-folder. The image is the
     * payment QR only; stale copies are removed on every call.
     */
    private fun shareQrImage(bytes: ByteArray?, fileName: String?, mimeType: String?, result: MethodChannel.Result, cutoff: Long) {
        val name = validQrImage(bytes, fileName, mimeType)
        if (name == null || bytes == null) {
            result.error("INVALID_IMAGE", "Gambar QR tidak valid", null)
            return
        }
        try {
            val directory = File(cacheDir, "payment_qr")
            if (!directory.exists() && !directory.mkdirs()) throw IOException("No cache directory")
            val cutoff = System.currentTimeMillis() - STALE_QR_MILLIS
            directory.listFiles()?.forEach { if (it.lastModified() < cutoff) it.delete() }
            val file = File(directory, name)
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(this, "$packageName.payment_qr", file)
            val send = Intent(Intent.ACTION_SEND)
                .setType("image/png")
                .putExtra(Intent.EXTRA_STREAM, uri)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            send.clipData = ClipData.newRawUri("QR pembayaran", uri)
            if (SystemClock.elapsedRealtime() >= cutoff) {
                file.delete()
                result.success("expired")
                return
            }
            startActivity(Intent.createChooser(send, "Bagikan QR pembayaran"))
            result.success("shared")
        } catch (error: ActivityNotFoundException) {
            result.error("UNAVAILABLE", "Tidak ada aplikasi untuk berbagi", null)
        } catch (error: IOException) {
            Log.w("PaymentQrExport", "Share failed: ${error.javaClass.simpleName}")
            result.error("IO_ERROR", "QR gagal dibagikan", null)
        } catch (error: IllegalArgumentException) {
            result.error("IO_ERROR", "QR gagal dibagikan", null)
        }
    }

    private fun tryOpen(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (error: ActivityNotFoundException) {
        Log.i("DestinationDirections", "No activity for ${intent.`package`}")
        false
    } catch (error: SecurityException) {
        Log.w("DestinationDirections", "Activity blocked for ${intent.`package`}")
        false
    }

    private companion object {
        const val SAVE_QR_REQUEST = 7301
        const val MAX_QR_BYTES = 5 * 1024 * 1024
        const val STALE_QR_MILLIS = 60 * 60 * 1000L
    }
}
