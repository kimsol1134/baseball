package com.solkim.baseball.android

/** JNI/AndroidJavaClass callback target used only for versioned Unity lifecycle acknowledgements. */
public object UnityBridgeCallbacks {
    public interface Listener {
        public fun onBridgeAcknowledgement(json: String)
    }

    private var listener: Listener? = null

    @JvmStatic
    public fun bind(listener: Listener) {
        this.listener = listener
    }

    @JvmStatic
    public fun unbind(listener: Listener) {
        if (this.listener === listener) this.listener = null
    }

    @JvmStatic
    public fun onBridgeAcknowledgement(json: String) {
        listener?.onBridgeAcknowledgement(json)
    }
}
