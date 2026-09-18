package com.solkim.baseball.android

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.webkit.*
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.solkim.baseball.design.BaseballMigrationTheme
import com.solkim.baseball.android.LocalizedGameText as Text

/** Read-only policy pages must not depend on completing a browser's first-run setup. */
class PolicyDocumentActivity : ComponentActivity() {
    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val url = intent.getStringExtra("url")
        if (url !in setOf(PolicyLinks.PRIVACY, PolicyLinks.SUPPORT)) { finish(); return }
        setContent { BaseballMigrationTheme {
            val copy = rememberGameCopy()
            var loading by remember { mutableStateOf(true) }
            var failed by remember { mutableStateOf(false) }
            var browserError by remember { mutableStateOf(false) }
            var webView by remember { mutableStateOf<WebView?>(null) }
            BackHandler { if (webView?.canGoBack() == true) webView?.goBack() else finish() }
            DisposableEffect(Unit) { onDispose { webView?.stopLoading(); webView?.destroy() } }
            Scaffold(topBar = { TopAppBar(title = { Text(copy.resolve(if (url == PolicyLinks.PRIVACY) "settings2.privacy" else "settings2.support"), verbatim=true) },
                navigationIcon = { TextButton(onClick = { finish() }, modifier=Modifier.testTag("policy.close")) { Text(copy.resolve("settings2.close"),verbatim=true) } }) },
                bottomBar = { Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal=12.dp)) {
                    if (browserError) Text(copy.resolve("settings2.link-error"),verbatim=true)
                    Row {
                        TextButton(onClick = { browserError = PolicyLinks.open(this@PolicyDocumentActivity, requireNotNull(url)) == PolicyLinks.Launch.UNAVAILABLE },modifier=Modifier.testTag("policy.browser")) { Text("브라우저로 열기") }
                        TextButton(onClick = {
                            getSystemService(android.content.ClipboardManager::class.java).setPrimaryClip(android.content.ClipData.newPlainText("URL",url))
                        },modifier=Modifier.testTag("policy.copy")) { Text("주소 복사") }
                    }
                } }) { insets ->
                Column(Modifier.fillMaxSize().padding(insets)) {
                    if (loading) LinearProgressIndicator(Modifier.fillMaxWidth())
                    if (failed) Column(Modifier.padding(20.dp)) {
                        Text("페이지를 열지 못했어요. 다시 시도하거나 브라우저로 열어 주세요.")
                        TextButton(onClick = { failed=false; if (webView == null) recreate() else webView?.reload() },modifier=Modifier.testTag("policy.retry")) { Text("다시 시도") }
                    }
                    AndroidView(modifier=Modifier.weight(1f).fillMaxWidth(), factory = { context ->
                        try { WebView(context).apply {
                            settings.javaScriptEnabled=false
                            settings.allowFileAccess=false
                            settings.allowContentAccess=false
                            settings.mixedContentMode=WebSettings.MIXED_CONTENT_NEVER_ALLOW
                            webViewClient=object:WebViewClient() {
                                override fun onPageStarted(view:WebView, current:String, icon:android.graphics.Bitmap?) { loading=true; failed=false }
                                override fun onPageFinished(view:WebView, current:String) { loading=false }
                                override fun onReceivedError(view:WebView, request:WebResourceRequest, error:WebResourceError) {
                                    if(request.isForMainFrame) { loading=false; failed=true }
                                }
                                override fun onReceivedSslError(view:WebView, handler:SslErrorHandler, error:android.net.http.SslError) {
                                    handler.cancel(); loading=false; failed=true
                                }
                                override fun onReceivedHttpError(view:WebView, request:WebResourceRequest, response:WebResourceResponse) {
                                    if(request.isForMainFrame && response.statusCode>=400) { loading=false; failed=true }
                                }
                                override fun shouldOverrideUrlLoading(view:WebView, request:WebResourceRequest):Boolean {
                                    val uri=request.url
                                    if(uri.scheme=="https" && uri.host=="baseball-reincarnation.vercel.app") return false
                                    if(request.hasGesture() && uri.scheme in setOf("https","mailto")) {
                                        try { startActivity(Intent(Intent.ACTION_VIEW,uri)) }
                                        catch (_:android.content.ActivityNotFoundException) { browserError=true }
                                        catch (_:SecurityException) { browserError=true }
                                    }
                                    return true
                                }
                            }
                            webView=this
                            loadUrl(requireNotNull(url))
                        } } catch (error: RuntimeException) {
                            android.util.Log.w("PolicyDocument", "WebView unavailable", error)
                            loading=false; failed=true
                            android.widget.FrameLayout(context)
                        }
                    })
                }
            }
        } }
    }

    companion object {
        fun intent(context:Context,url:String):Intent {
            require(url==PolicyLinks.PRIVACY || url==PolicyLinks.SUPPORT)
            return Intent(context,PolicyDocumentActivity::class.java).putExtra("url",url)
        }
    }
}
