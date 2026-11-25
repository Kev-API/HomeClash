package com.home.clash

import com.home.clash.plugins.AppPlugin
import com.home.clash.plugins.BatteryPlugin
import com.home.clash.plugins.LinkPlugin
import com.home.clash.plugins.ServicePlugin
import com.home.clash.plugins.TilePlugin
import com.home.clash.plugins.WifiSsidPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(BatteryPlugin())
        flutterEngine.plugins.add(LinkPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        flutterEngine.plugins.add(WifiSsidPlugin())
        ServiceState.attachFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        flutterEngine?.let(ServiceState::detachFlutterEngine)
        super.onDestroy()
    }
}
