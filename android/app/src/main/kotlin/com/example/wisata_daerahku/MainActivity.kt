package com.example.wisata_daerahku

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
