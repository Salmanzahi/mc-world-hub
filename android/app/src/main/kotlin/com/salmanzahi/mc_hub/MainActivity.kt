package com.salmanzahi.mc_hub

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "mc_hub/lan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBroadcast" -> {
                    val intent = Intent(this, LanBroadcasterService::class.java).apply {
                        putExtra(LanBroadcasterService.EXTRA_NAME, call.argument<String>("name") ?: "World")
                        putExtra(LanBroadcasterService.EXTRA_IP, call.argument<String>("ip") ?: "172.197.221.186")
                        putExtra(LanBroadcasterService.EXTRA_PORT, call.argument<Int>("port") ?: 19132)
                        putExtra(LanBroadcasterService.EXTRA_PLAYERS, call.argument<Int>("players") ?: 0)
                    }
                    startForegroundService(intent)
                    result.success(true)
                }
                "stopBroadcast" -> {
                    val intent = Intent(this, LanBroadcasterService::class.java).apply {
                        action = "STOP"
                    }
                    startService(intent)
                    result.success(true)
                }
                "isBroadcasting" -> {
                    result.success(LanBroadcasterService.isRunning)
                }
                else -> result.notImplemented()
            }
        }
    }
}
