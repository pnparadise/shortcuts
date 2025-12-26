package com.shortcuts.shortcuts.utils

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

class ToastActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        overridePendingTransition(0, 0)
        super.onCreate(savedInstanceState)
        
        val msg = intent.getStringExtra("message") ?: ""
        if (msg.isNotEmpty()) {
            val inflater = android.view.LayoutInflater.from(this)
            val layout = inflater.inflate(com.shortcuts.shortcuts.R.layout.custom_toast, null)
            layout.findViewById<android.widget.TextView>(com.shortcuts.shortcuts.R.id.toast_text).text = msg
            
            val toast = Toast(applicationContext)
            toast.duration = Toast.LENGTH_SHORT
            try {
                @Suppress("DEPRECATION")
                toast.view = layout
                toast.setGravity(android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL, 0, 200)
                toast.show()
            } catch (e: Exception) {
                // Fallback for Android 12+ if custom view fails (though it shouldn't in foreground)
                Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
            }
        }
        
        finish()
        overridePendingTransition(0, 0)
    }
}

