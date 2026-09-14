package com.makund.combouniversal

import android.app.Application
import java.io.File

class ComboUniversalApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        File(cacheDir, "WebView/Crashpad").mkdirs()
    }
}
