package com.solkim.baseball.bridge

import android.app.Activity
import android.util.Log
import android.view.View
import android.view.ViewGroup
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Method
import java.lang.reflect.Proxy

/**
 * Reflection keeps the shadow-read-only Compose build compilable before a Unity export exists.
 * When `unityLibrary` is included, this class loads the real UnityPlayer; there is no fake
 * renderer fallback in this host.
 */
public class UnityRuntimeHost {
    private var activityRef: java.lang.ref.WeakReference<Activity>? = null
    private var unityPlayerClass: Class<*>? = null
    private var unityPlayer: Any? = null
    private var unityView: View? = null
    private var unityLifecycleEvents: Any? = null
    private var unloadRequested = false
    private var closeCompleted = false
    private var closeCompletion: (() -> Unit)? = null

    public val isAttached: Boolean get() = unityPlayer != null && unityView?.parent != null

    public fun attach(activity: Activity, parent: ViewGroup) {
        activityRef = java.lang.ref.WeakReference(activity)
        val existingPlayer = unityPlayer
        if (existingPlayer != null) {
            synchronized(this) {
                check(!unloadRequested || closeCompleted) { "unity.runtime.reopen_during_unload" }
                unloadRequested = false
                closeCompleted = false
                closeCompletion = null
            }
            val existingView = requireNotNull(unityView) { "unity.runtime.view_missing" }
            (existingView.parent as? ViewGroup)?.removeView(existingView)
            parent.addView(
                existingView,
                0,
                ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
            )
            invokeOptional("resume", existingPlayer)
            existingPlayer.javaClass.getMethod("windowFocusChanged", Boolean::class.javaPrimitiveType)
                .invoke(existingPlayer, true)
            return
        }
        val playerClass = try {
            // Unity 6 exports UnityPlayer as an abstract API and exposes the concrete
            // Activity/Service host as UnityPlayerForActivityOrService.
            Class.forName("com.unity3d.player.UnityPlayerForActivityOrService")
        } catch (error: ClassNotFoundException) {
            throw UnityRuntimeUnavailableException("unity.export.missing", error)
        }
        try {
            val lifecycleInterface = Class.forName("com.unity3d.player.IUnityPlayerLifecycleEvents")
            val lifecycleEvents = Proxy.newProxyInstance(
                lifecycleInterface.classLoader,
                arrayOf(lifecycleInterface),
                InvocationHandler { _, method, _ ->
                    Log.d(TAG, "Unity lifecycle callback=${method.name}")
                    if (method.name == "onUnityPlayerUnloaded") completeClose()
                    null
                },
            )
            val player = playerClass.getConstructor(
                android.content.Context::class.java,
                lifecycleInterface,
            ).newInstance(activity, lifecycleEvents)
            val view = runCatching { playerClass.getMethod("getFrameLayout").invoke(player) as? View }
                .getOrNull()
                ?: playerClass.getMethod("getView").invoke(player) as? View
                ?: error("unity.player.not_a_view")
            view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            view.isClickable = false
            view.isFocusable = false
            (view.parent as? ViewGroup)?.removeView(view)
            parent.addView(
                view,
                ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
            )
            unityPlayerClass = playerClass
            unityPlayer = player
            unityView = view
            unityLifecycleEvents = lifecycleEvents
        } catch (error: Exception) {
            throw UnityRuntimeUnavailableException("unity.runtime.attach_failed", error)
        }
    }

    public fun sendCommand(json: String) {
        checkNotNull(unityPlayerClass) { "unity.runtime.not_attached" }
        checkNotNull(unityPlayer) { "unity.runtime.not_attached" }
        check(!unloadRequested && !closeCompleted) { "unity.runtime.not_active" }
        try {
            // Unity 6 keeps UnitySendMessage on the abstract UnityPlayer API while the
            // concrete ActivityOrService class owns the instantiated runtime.
            val bridgeClass = Class.forName("com.unity3d.player.UnityPlayer")
            val send = bridgeClass.getMethod(
                "UnitySendMessage",
                String::class.java,
                String::class.java,
                String::class.java,
            )
            Log.d(TAG, "UnitySendMessage target=PitchBridgeReceiver bytes=${json.toByteArray(Charsets.UTF_8).size}")
            send.invoke(null, "PitchBridgeReceiver", "ReceiveCommand", json)
        } catch (error: Exception) {
            Log.e(TAG, "UnitySendMessage failed", error)
            throw UnityRuntimeUnavailableException("unity.bridge.send_failed", error)
        }
    }

    public fun onResume() {
        invokeOptionalIfActive("resume")
    }

    public fun onStart() {
        invokeOptionalIfActive("onStart")
    }

    public fun onStop() {
        invokeOptionalIfActive("onStop")
    }

    public fun onWindowFocusChanged(hasFocus: Boolean) {
        val player = activePlayer() ?: return
        runCatching {
            player.javaClass.getMethod("windowFocusChanged", Boolean::class.javaPrimitiveType)
                .invoke(player, hasFocus)
        }
    }

    public fun onPause() {
        invokeOptionalIfActive("pause")
    }

    public fun onLowMemory() {
        invokeOptionalIfActive("lowMemory")
    }

    /**
     * Unloads the one runtime instance. Never calls UnityPlayer.quit(). Completion is
     * deliberately deferred until Unity's lifecycle callback so a new host cannot race
     * the native unload while the Activity is returning to the Compose shell.
     */
    public fun close(onComplete: () -> Unit = {}) {
        val player: Any?
        synchronized(this) {
            if (closeCompleted || unityPlayer == null) {
                onComplete()
                return
            }
            if (unloadRequested) {
                val previous = closeCompletion
                closeCompletion = {
                    previous?.invoke()
                    onComplete()
                }
                return
            }
            unloadRequested = true
            closeCompletion = onComplete
            player = unityPlayer
        }
        invokeOptional("unload", player)
    }

    /**
     * Normal pitch-session return uses the pause policy: remove the full-screen surface while
     * retaining the one Unity runtime and its pitch receiver for same-process re-entry.
     * Destructive runtime unload remains available through [close] for an explicit host teardown.
     */
    public fun pauseAndDetach(onComplete: () -> Unit = {}) {
        val player = synchronized(this) {
            if (unityPlayer == null || closeCompleted || unloadRequested) {
                onComplete()
                return
            }
            unityPlayer
        }
        invokeOptional("pause", player)
        val view = unityView
        val activity = activityRef?.get()
        if (activity == null) {
            (view?.parent as? ViewGroup)?.removeView(view)
            onComplete()
            return
        }
        activity.runOnUiThread {
            (view?.parent as? ViewGroup)?.removeView(view)
            onComplete()
        }
    }

    private fun completeClose() {
        val completion: (() -> Unit)?
        val view: View?
        synchronized(this) {
            if (closeCompleted) return
            closeCompleted = true
            completion = closeCompletion
            closeCompletion = null
            view = unityView
        }
        val activity = activityRef?.get()
        if (activity == null) {
            (view?.parent as? ViewGroup)?.removeView(view)
            completion?.invoke()
            return
        }
        activity.runOnUiThread {
            (view?.parent as? ViewGroup)?.removeView(view)
            completion?.invoke()
        }
    }

    private fun invokeOptional(name: String, receiver: Any? = unityPlayer) {
        if (receiver == null) return
        val method: Method = runCatching { receiver.javaClass.getMethod(name) }.getOrNull() ?: return
        runCatching { method.invoke(receiver) }
    }

    private fun invokeOptionalIfActive(name: String) {
        invokeOptional(name, activePlayer())
    }

    private fun activePlayer(): Any? = synchronized(this) {
        if (unloadRequested || closeCompleted) null else unityPlayer
    }

    private companion object {
        const val TAG = "UnityRuntimeHost"
    }
}

public class UnityRuntimeUnavailableException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

/**
 * Unity as a Library permits one runtime instance per process. Keeping the host here lets a
 * later PitchUnityActivity reattach the same unloaded player instead of constructing a second
 * native graphics device after the first pitch.
 */
public object UnityRuntimeHostRegistry {
    @Volatile
    private var instance: UnityRuntimeHost? = null

    @Synchronized
    public fun get(): UnityRuntimeHost {
        val existing = instance
        if (existing != null) return existing
        return UnityRuntimeHost().also { instance = it }
    }
}
