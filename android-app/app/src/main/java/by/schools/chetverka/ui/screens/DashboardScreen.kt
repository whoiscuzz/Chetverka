package by.schools.chetverka.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bookmark
import androidx.compose.material.icons.rounded.Bookmarks
import androidx.compose.material.icons.rounded.CalendarToday
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Insights
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import by.schools.chetverka.ui.DiaryUiState
import by.schools.chetverka.ui.EmptyState
import by.schools.chetverka.ui.theme.AccentDanger
import by.schools.chetverka.ui.theme.AccentSuccess
import by.schools.chetverka.ui.theme.AccentWarning
import by.schools.chetverka.ui.theme.BlueDeep
import by.schools.chetverka.ui.theme.BluePrimary
import by.schools.chetverka.ui.theme.BlueSecondary
import by.schools.chetverka.ui.theme.BlueSky
import by.schools.chetverka.ui.theme.CardWhite
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun DashboardScreen(
    padding: PaddingValues,
    state: DiaryUiState
) {
    if (!state.isLoaded && state.isLoading) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            CircularProgressIndicator()
        }
        return
    }

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
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        contentPadding = PaddingValues(
            start = 0.dp,
            top = padding.calculateTopPadding() + 14.dp,
            end = 0.dp,
            bottom = padding.calculateBottomPadding() + 24.dp
        )
    ) {
        item {
            HeroCard(
                greeting = state.stats.randomGreeting,
                date = LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE, d MMMM", Locale("ru"))),
                error = state.error
            )
        }
        item {
            StatRow(
                title1 = "Уроков",
                value1 = state.stats.lessonsToday,
                title2 = "ДЗ",
                value2 = state.stats.homeworkToday,
                title3 = "Средний",
                value3 = state.stats.overallAverage
            )
        }

        item { BlockTitle("Уроки на сегодня", "Расписание и домашка") }
        if (state.stats.todayLessonsList.isEmpty()) {
            item { InfoCard("Сегодня уроков нет 🎉") }
        } else {
            items(state.stats.todayLessonsList) { lesson ->
                LessonCard(
                    subject = lesson.subject,
                    mark = lesson.mark ?: "—",
                    homework = lesson.hw.orEmpty().ifBlank { "Без ДЗ" }
                )
            }
        }

        item { BlockTitle("Последние оценки", "Твой свежий прогресс") }
        if (state.stats.recentLessons.isEmpty()) {
            item { InfoCard("Оценок пока нет") }
        } else {
            items(state.stats.recentLessons) { item ->
                RecentMarkCard(subject = item.first, mark = item.second)
            }
        }

        item { BlockTitle("Требуют внимания", "Прокачаем эти предметы") }
        if (state.stats.subjectsForAttention.isEmpty()) {
            item { InfoCard("Проблемных предметов нет 👍") }
        } else {
            items(state.stats.subjectsForAttention) { item ->
                AttentionCard(subject = item.first, average = item.second)
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
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        StatCard(
            title = title1,
            value = value1,
            icon = Icons.Rounded.CalendarToday,
            tint = BluePrimary,
            modifier = Modifier.weight(1f)
        )
        StatCard(
            title = title2,
            value = value2,
            icon = Icons.Rounded.Bookmarks,
            tint = BlueSecondary,
            modifier = Modifier.weight(1f)
        )
        StatCard(
            title = title3,
            value = value3,
            icon = Icons.Rounded.Insights,
            tint = BlueDeep,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun HeroCard(
    greeting: String,
    date: String,
    error: String?
) {
    Card(
        shape = RoundedCornerShape(26.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        elevation = CardDefaults.cardElevation(defaultElevation = 12.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(BluePrimary, BlueSecondary, BlueDeep)
                    )
                )
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(
                    imageVector = Icons.Rounded.CalendarToday,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = date.replaceFirstChar { it.uppercase() },
                    color = Color.White.copy(alpha = 0.95f),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
            Text(
                text = greeting,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            if (!error.isNullOrBlank()) {
                Text(
                    text = "⚠ $error",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White
                )
            }
        }
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String,
    icon: ImageVector,
    tint: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.8f))
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = BlueDeep
            )
            Text(
                text = title,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun BlockTitle(title: String, subtitle: String) {
    Column(modifier = Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun LessonCard(subject: String, mark: String, homework: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        shape = RoundedCornerShape(22.dp),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.72f))
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    text = subject,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
                MarkPill(mark = mark)
            }
            Text(
                text = homework,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun RecentMarkCard(subject: String, mark: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.72f))
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Rounded.Bookmark,
                contentDescription = null,
                tint = BluePrimary,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = subject,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f)
            )
            MarkPill(mark = mark)
        }
    }
}

@Composable
private fun AttentionCard(subject: String, average: Double) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.72f))
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Rounded.ErrorOutline,
                contentDescription = null,
                tint = AccentWarning,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = subject,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = "%.2f".format(average),
                style = MaterialTheme.typography.titleMedium,
                color = if (average < 5.5) AccentDanger else AccentWarning,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun InfoCard(text: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.72f))
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Rounded.Bookmarks,
                contentDescription = null,
                tint = AccentSuccess,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = text,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

@Composable
private fun MarkPill(mark: String) {
    val markInt = mark.toIntOrNull()
    val tint = when {
        markInt == null -> BlueSecondary
        markInt >= 9 -> AccentSuccess
        markInt >= 7 -> BluePrimary
        markInt >= 5 -> AccentWarning
        else -> AccentDanger
    }
    Card(
        colors = CardDefaults.cardColors(containerColor = tint.copy(alpha = 0.12f)),
        shape = RoundedCornerShape(12.dp)
    ) {
        Text(
            text = mark,
            color = tint,
            fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
        )
    }
}
