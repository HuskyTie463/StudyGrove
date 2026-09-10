package com.adaracurry.studygrove

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.adaracurry.studygrove/home_widget",
        ).setMethodCallHandler { call, result ->
            if (call.method == "pinHomeWidget") {
                result.success(requestPinHomeWidget())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun requestPinHomeWidget(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return "unsupported"
        }
        val manager = AppWidgetManager.getInstance(this)
        if (!manager.isRequestPinAppWidgetSupported) {
            return "unsupported"
        }
        val provider = ComponentName(this, StudyGroveHomeWidgetProvider::class.java)
        val sent = manager.requestPinAppWidget(provider, null, null)
        return if (sent) "pinned" else "unsupported"
    }
}
