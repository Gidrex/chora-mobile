package dev.gidrex.chora_mobile

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "dev.gidrex.chora_mobile/syncthing"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val lib = File("${applicationInfo.nativeLibraryDir}/libsyncthing.so")
                    if (!lib.exists()) {
                        result.error(
                            "NO_BINARY",
                            "libsyncthing.so is not bundled with this build",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    val intent = Intent(this, SyncthingService::class.java).apply {
                        action = SyncthingService.ACTION_START
                        putExtra("choraDir", call.argument<String>("choraDir"))
                        putExtra("apiKey", call.argument<String>("apiKey"))
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stop" -> {
                    val intent = Intent(this, SyncthingService::class.java).apply {
                        action = SyncthingService.ACTION_STOP
                        putExtra("apiKey", call.argument<String>("apiKey"))
                    }
                    startService(intent)
                    result.success(null)
                }
                "isRunning" -> result.success(SyncthingService.isRunning())
                else -> result.notImplemented()
            }
        }
    }
}
