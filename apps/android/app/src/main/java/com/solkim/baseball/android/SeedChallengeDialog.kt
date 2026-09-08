package com.solkim.baseball.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.GameCopyArgument
import com.solkim.baseball.application.HighSchoolDisplayRules
import com.solkim.baseball.application.SeedChallengeCode
import com.solkim.baseball.platform.NativeAchievementShareService

@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
internal fun SeedChallengeDialog(
    pending: SeedChallengeCode?,
    canStart: Boolean,
    onStart: (SeedChallengeCode, String) -> Unit,
    onRemember: (SeedChallengeCode) -> Unit,
    onDismiss: () -> Unit,
) {
    val copy = rememberGameCopy()
    val context = LocalContext.current
    val appName = stringResource(R.string.app_name)
    var input by rememberSaveable(pending?.token) { mutableStateOf(pending?.token.orEmpty()) }
    var preset by rememberSaveable { mutableStateOf("power_prospect") }
    val parsed = SeedChallengeCode.parse(input)
    AlertDialog(
        modifier = Modifier.semantics { testTagsAsResourceId = true },
        onDismissRequest = onDismiss,
        title = { Text(copy.resolve("android.challenge.title")) },
        text = {
            Column(Modifier.heightIn(max = 480.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(copy.resolve("android.challenge.explanation"))
                OutlinedTextField(value = input, onValueChange = { input = it.take(2048) },
                    label = { Text(copy.resolve("android.challenge.code")) },
                    placeholder = { Text("친구가 보낸 코드 (숫자-숫자)") }, singleLine = true,
                    isError = input.contains('-') && parsed == null,
                    modifier = Modifier.fillMaxWidth().testTag("challenge.code"))
                AdaptiveActionRow(Modifier.fillMaxWidth()) {
                    TextButton(onClick = { input = "${java.security.SecureRandom().nextLong().toULong()}-1" }, modifier = Modifier.testTag("challenge.generate")) {
                        Text(copy.resolve("android.challenge.generate"))
                    }
                    TextButton(enabled = parsed != null, onClick = {
                        val code = parsed ?: return@TextButton
                        onRemember(code)
                        NativeAchievementShareService(context).share(copy.resolve("android.challenge.invitation"),
                            copy.resolve("android.challenge.share-code", GameCopyArgument.UserText(code.token)),
                            appName, "https://play.google.com/store/apps/details?id=com.solkim.baseball.android", code.webUrl)
                    }, modifier = Modifier.testTag("challenge.share")) { Text(copy.resolve("android.challenge.share")) }
                }
                Text(copy.resolve("android.challenge.style"))
                HighSchoolDisplayRules.presets.forEach { choice ->
                    SetupSelectionButton(selected = preset == choice.id, onClick = { preset = choice.id }, modifier = Modifier.fillMaxWidth()) {
                        Text(copy.resolve("android.challenge.preset.${choice.id}"))
                    }
                }
                if (!canStart) Text(copy.resolve("android.challenge.wait"))
            }
        },
        confirmButton = {
            TextButton(enabled = canStart && parsed != null, onClick = { parsed?.let { onStart(it, preset) } }, modifier = Modifier.testTag("challenge.start")) {
                Text(copy.resolve("android.challenge.start"))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(copy.resolve("android.challenge.later")) } },
    )
}
