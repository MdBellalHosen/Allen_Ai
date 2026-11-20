package com.allen.allen_ai.actions

import android.content.Context
import android.media.AudioManager
import android.os.SystemClock
import android.view.KeyEvent

class MediaController(ctx: Context) {
    private val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun key(code: Int) {
        val t = SystemClock.uptimeMillis()
        am.dispatchMediaKeyEvent(KeyEvent(t, t, KeyEvent.ACTION_DOWN, code, 0))
        am.dispatchMediaKeyEvent(KeyEvent(t, t, KeyEvent.ACTION_UP, code, 0))
    }

    /** action: play | pause | toggle | next | previous | forward | rewind | stop */
    fun control(action: String): Boolean {
        val code = when (action) {
            "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
            "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
            "toggle" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            "forward" -> KeyEvent.KEYCODE_MEDIA_FAST_FORWARD
            "rewind" -> KeyEvent.KEYCODE_MEDIA_REWIND
            "stop" -> KeyEvent.KEYCODE_MEDIA_STOP
            else -> return false
        }
        key(code)
        return true
    }

    private fun percent(): Int {
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        return am.getStreamVolume(AudioManager.STREAM_MUSIC) * 100 / max
    }

    /** direction: up | down | mute | unmute, or set an absolute level 0..100. Returns resulting percent. */
    fun volume(direction: String?, level: Int?): Int {
        val s = AudioManager.STREAM_MUSIC
        if (level != null) {
            val max = am.getStreamMaxVolume(s)
            am.setStreamVolume(s, (level.coerceIn(0, 100) * max + 50) / 100, AudioManager.FLAG_SHOW_UI)
        } else {
            val dir = when (direction) {
                "up" -> AudioManager.ADJUST_RAISE
                "down" -> AudioManager.ADJUST_LOWER
                "mute" -> AudioManager.ADJUST_MUTE
                "unmute" -> AudioManager.ADJUST_UNMUTE
                else -> return percent()
            }
            am.adjustStreamVolume(s, dir, AudioManager.FLAG_SHOW_UI)
        }
        return percent()
    }
}
