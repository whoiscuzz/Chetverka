package by.schools.chetverka.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BugReport
import androidx.compose.material.icons.rounded.ExitToApp
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.PostAdd
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import by.schools.chetverka.data.api.ProfileDto
import by.schools.chetverka.ui.theme.BlueDeep
import by.schools.chetverka.ui.theme.BluePrimary
import by.schools.chetverka.ui.theme.BlueSky
import by.schools.chetverka.ui.theme.CardWhite
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

@Composable
fun ProfileScreen(
    padding: PaddingValues,
    profile: ProfileDto?,
    isAdmin: Boolean,
    newsError: String?,
    onReload: () -> Unit,
    onPublishNews: (title: String, body: String, imageUrl: String?) -> Unit,
    onLogout: () -> Unit
) {
    val uriHandler = LocalUriHandler.current
    var showPublishDialog by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = padding.calculateTopPadding() + 12.dp),
            shape = RoundedCornerShape(30.dp),
            colors = CardDefaults.cardColors(containerColor = CardWhite),
            border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.75f)),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Card(
                    shape = CircleShape,
                    colors = CardDefaults.cardColors(containerColor = BlueSky),
                    modifier = Modifier.size(66.dp)
                ) {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = profile?.fullName?.firstOrNull()?.uppercase() ?: "👤",
                            style = MaterialTheme.typography.headlineMedium,
                            color = BlueDeep,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(
                        text = profile?.fullName ?: "Профиль не загружен",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                    if (!profile?.className.isNullOrBlank()) {
                        Text(
                            text = "${profile?.className} класс",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (!profile?.classTeacher.isNullOrBlank()) {
                        Text(
                            text = "Классный: ${profile?.classTeacher}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        OutlinedButton(
            onClick = onReload,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.8f))
        ) {
            Icon(imageVector = Icons.Rounded.Refresh, contentDescription = null)
            Text(" Обновить дневник")
        }

        if (isAdmin) {
            OutlinedButton(
                onClick = { showPublishDialog = true },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
                border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.8f))
            ) {
                Icon(imageVector = Icons.Rounded.PostAdd, contentDescription = null)
                Text(" Опубликовать новость")
            }
        }

        OutlinedButton(
            onClick = {
                val subject = uriEncode("Chetverka Android: Проблема")
                val body = uriEncode("Что произошло:\n")
                uriHandler.openUri("mailto:chetverka@proton.me?subject=$subject&body=$body")
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.8f))
        ) {
            Icon(imageVector = Icons.Rounded.BugReport, contentDescription = null)
            Text(" Сообщить о проблеме")
        }

        OutlinedButton(
            onClick = {
                val subject = uriEncode("Chetverka Android: Идея")
                val body = uriEncode("Хочу предложить улучшение:\n")
                uriHandler.openUri("mailto:chetverka@proton.me?subject=$subject&body=$body")
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.8f))
        ) {
            Icon(imageVector = Icons.Rounded.Lightbulb, contentDescription = null)
            Text(" Предложить идею")
        }

        Button(
            onClick = onLogout,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = BluePrimary)
        ) {
            Icon(
                imageVector = Icons.Rounded.ExitToApp,
                contentDescription = null,
                tint = Color.White
            )
            Text(" Выйти", color = Color.White)
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(22.dp),
            colors = CardDefaults.cardColors(containerColor = CardWhite),
            border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.75f))
        ) {
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "О приложении",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "Четвёрка • Android Edition",
                    style = MaterialTheme.typography.bodyMedium
                )
                if (!newsError.isNullOrBlank()) {
                    Text(
                        text = "Новости: $newsError",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        }
    }

    if (showPublishDialog) {
        PublishNewsDialog(
            onDismiss = { showPublishDialog = false },
            onPublish = { title, body, imageUrl ->
                onPublishNews(title, body, imageUrl)
                showPublishDialog = false
            }
        )
    }
}

@Composable
private fun PublishNewsDialog(
    onDismiss: () -> Unit,
    onPublish: (title: String, body: String, imageUrl: String?) -> Unit
) {
    var title by remember { mutableStateOf("") }
    var body by remember { mutableStateOf("") }
    var imageUrl by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Новая новость") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Заголовок") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                OutlinedTextField(
                    value = body,
                    onValueChange = { body = it },
                    label = { Text("Текст") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 4
                )
                OutlinedTextField(
                    value = imageUrl,
                    onValueChange = { imageUrl = it },
                    label = { Text("Ссылка на фото (https://...) ") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val cleanImageUrl = imageUrl.trim().ifBlank { null }
                    onPublish(title.trim(), body.trim(), cleanImageUrl)
                },
                enabled = title.isNotBlank() && body.isNotBlank()
            ) {
                Text("Опубликовать")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Отмена")
            }
        }
    )
}

private fun uriEncode(value: String): String {
    return URLEncoder.encode(value, StandardCharsets.UTF_8.toString())
}
