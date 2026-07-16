package com.example.sos

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class VolumeButtonService : AccessibilityService() {

    private var lastClickTime: Long = 0
    private var clickCount = 0

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP && event.action == KeyEvent.ACTION_DOWN) {
            val currentTime = System.currentTimeMillis()
            
            if (currentTime - lastClickTime > 2000) {
                clickCount = 0 // تصفير إذا تأخر
            }
            
            clickCount++
            lastClickTime = currentTime

            if (clickCount >= 5) {
                clickCount = 0
                triggerEmergency()
            }
        }
        return super.onKeyEvent(event)
    }

    private fun triggerEmergency() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("trigger_sos", true)
        }
        startActivity(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}
}
