package com.solkim.baseball.android

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun CareerBackupControls(state: GameAggregateState) {
    val context = LocalContext.current
    val store = (context.applicationContext as BaseballApplication).gameStore
    if (!store.supportsCareerBackup) return
    val scope = rememberCoroutineScope()
    var working by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var pending by remember { mutableStateOf<ByteArray?>(null) }
    var preview by remember { mutableStateOf<GameAggregateState?>(null) }
    var expectedRevision by remember { mutableStateOf(0UL) }
    val save = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) scope.launch {
            working = true
            try {
                val bytes = store.exportCareerBackup()
                withContext(Dispatchers.IO) { requireNotNull(context.contentResolver.openOutputStream(uri, "wt")).use { it.write(bytes) } }
                message = "기록을 파일로 보관했어요. 다른 기기에서도 이 파일을 불러올 수 있어요."
            } catch (error: Exception) {
                if (error is kotlinx.coroutines.CancellationException) throw error
                message = "파일을 저장하지 못했어요. 저장할 위치를 확인하고 다시 시도해 주세요."
            } finally { working = false }
        }
    }
    val open = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch {
            working = true
            try {
                val bytes = withContext(Dispatchers.IO) {
                    requireNotNull(context.contentResolver.openInputStream(uri)).use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            require(output.size() + count <= CareerBackup.MAX_BYTES) { "backup.size" }
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                }
                preview = withContext(Dispatchers.IO) { CareerBackup.preview(bytes) }
                expectedRevision = store.current.revision
                pending = bytes
            } catch (error: Exception) {
                if (error is kotlinx.coroutines.CancellationException) throw error
                pending = null; preview = null
                message = "읽을 수 없는 백업 파일이에요. 현재 기록은 그대로 유지돼요."
            } finally { working = false }
        }
    }
    Text("기록 보관과 복원", style = MaterialTheme.typography.titleMedium)
    Text("기기를 바꾸거나 앱을 지우기 전에 기록을 파일로 보관해 주세요.")
    OutlinedButton(onClick = { save.launch("baseball-career.json") }, enabled = !working && (state.highSchool != null || state.pro != null),
        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("backup.export")) { Text("기록을 파일로 보관") }
    OutlinedButton(onClick = { open.launch(arrayOf("application/json", "application/octet-stream")) }, enabled = !working,
        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("backup.import")) { Text("보관한 기록 불러오기") }
    message?.let { Text(it) }
    val ready = preview
    if (pending != null && ready != null) AlertDialog(onDismissRequest = { pending = null; preview = null },
        title = { Text("이 기록으로 이어 할까요?") },
        text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val activePro = ready.pro?.takeIf { ready.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY) }
            Text(activePro?.identityName ?: ready.highSchool?.run?.identity?.name.orEmpty(), verbatim = true)
            if (activePro != null) Text("${ready.highSchool?.run?.lifeNumber ?: 1}번째 생 · 프로 ${activePro.season}시즌")
            else Text("${ready.highSchool?.run?.lifeNumber ?: 1}번째 생")
            Text("현재 진행 중인 기록이 이 파일의 기록으로 바뀝니다. 현재 기록을 남기려면 먼저 파일로 보관해 주세요.")
        } },
        confirmButton = { TextButton(onClick = {
            val bytes = pending ?: return@TextButton
            pending = null; preview = null
            scope.launch {
                working = true
                try { store.importCareerBackup(bytes, expectedRevision); message = "기록을 불러왔어요. 이어서 플레이해 보세요." }
                catch (error: Exception) {
                    if (error is kotlinx.coroutines.CancellationException) throw error
                    message = "기록을 불러오지 못했어요. 현재 기록을 확인한 뒤 다시 시도해 주세요."
                } finally { working = false }
            }
        }, modifier = Modifier.testTag("backup.confirm")) { Text("이 기록 불러오기") } },
        dismissButton = { TextButton(onClick = { pending = null; preview = null }) { Text("취소") } })
}
