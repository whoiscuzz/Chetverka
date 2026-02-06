package by.schools.chetverka.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import by.schools.chetverka.ui.DiaryUiState
import by.schools.chetverka.ui.EmptyState

@Composable
fun DashboardScreen(
    padding: PaddingValues,
    state: DiaryUiState
) {
    if (!state.isLoaded && !state.isLoading) {
        EmptyState(
            title = "Нет данных",
            subtitle = "Зайди в профиль и нажми «Обновить дневник».",
            padding = padding
        )
        return
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        item { Text(state.stats.randomGreeting, style = MaterialTheme.typography.headlineSmall) }
        item { StatRow("Уроков", state.stats.lessonsToday, "ДЗ", state.stats.homeworkToday, "Средний", state.stats.overallAverage) }

        item { BlockTitle("Уроки на сегодня") }
        if (state.stats.todayLessonsList.isEmpty()) {
            item { InfoCard("Сегодня уроков нет 🎉") }
        } else {
            items(state.stats.todayLessonsList) { lesson ->
                InfoCard("${lesson.subject}: ${lesson.hw.orEmpty().ifBlank { "Без ДЗ" }}")
            }
        }

        item { BlockTitle("Последние оценки") }
        if (state.stats.recentLessons.isEmpty()) {
            item { InfoCard("Оценок пока нет") }
        } else {
            items(state.stats.recentLessons) { item ->
                InfoCard("${item.first}: ${item.second}")
            }
        }

        item { BlockTitle("Требуют внимания") }
        if (state.stats.subjectsForAttention.isEmpty()) {
            item { InfoCard("Проблемных предметов нет 👍") }
        } else {
            items(state.stats.subjectsForAttention) { item ->
                InfoCard("${item.first}: %.2f".format(item.second))
            }
        }
    }
}

@Composable
private fun StatRow(
    title1: String,
    value1: String,
    title2: String,
    value2: String,
    title3: String,
    value3: String
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        InfoCard("$title1: $value1")
        InfoCard("$title2: $value2")
        InfoCard("$title3: $value3")
    }
}

@Composable
private fun BlockTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(top = 8.dp)
    )
}

@Composable
private fun InfoCard(text: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(14.dp),
            style = MaterialTheme.typography.bodyMedium
        )
    }
}
