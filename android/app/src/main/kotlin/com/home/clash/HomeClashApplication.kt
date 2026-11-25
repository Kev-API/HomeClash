package com.home.clash

import android.app.Application
import android.content.Context
import com.home.clash.common.GlobalState

class HomeClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
