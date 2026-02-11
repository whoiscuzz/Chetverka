package by.schools.chetverka.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Alarm
import androidx.compose.material.icons.rounded.Bookmarks
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.NotificationsNone
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
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

    val date = LocalDate.now()
    val monthTitle = date.format(DateTimeFormatter.ofPattern("LLL, yyyy", Locale("ru")))
        .replaceFirstChar { it.uppercase() }
    val dayTitle = date.format(DateTimeFormatter.ofPattern("d MMMM", Locale("ru")))
        .replaceFirstChar { it.uppercase() }
    val nextLesson = state.stats.todayLessonsList.firstOrNull()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        contentPadding = PaddingValues(
            start = 0.dp,
            top = padding.calculateTopPadding() + 12.dp,
            end = 0.dp,
            bottom = padding.calculateBottomPadding() + 24.dp
        )
    ) {
        item {
            GreetingCard(
                greeting = state.stats.randomGreeting,
                month = monthTitle,
                day = dayTitle,
                lessonCount = state.stats.lessonsToday
            )
        }

        item {
            NextTaskCard(
                subject = nextLesson?.subject ?: "Сегодня можно выдохнуть",
                subtitle = nextLesson?.hw.orEmpty().ifBlank { "Задач на сегодня нет" },
                mark = nextLesson?.mark ?: "--"
            )
        }

        item {
            SectionTitle(title = "Сегодня", subtitle = "Расписание и оценки")
        }

        if (state.stats.todayLessonsList.isEmpty()) {
            item { InfoCard(text = "Сегодня уроков нет") }
        } else {
            items(state.stats.todayLessonsList) { lesson ->
                LessonTaskCard(
                    subject = lesson.subject,
                    homework = lesson.hw.orEmpty().ifBlank { "Без домашнего задания" },
                    mark = lesson.mark ?: "--"
                )
            }
        }

        item {
            SectionTitle(title = "Требуют внимания", subtitle = "Предметы с низким средним")
        }

        if (state.stats.subjectsForAttention.isEmpty()) {
            item { InfoCard(text = "Проблемных предметов нет") }
        } else {
            items(state.stats.subjectsForAttention) { item ->
                AttentionCard(subject = item.first, average = item.second)
            }
        }

        item {
            SectionTitle(title = "Последние оценки", subtitle = "Свежий прогресс")
        }

        if (state.stats.recentLessons.isEmpty()) {
            item { InfoCard(text = "Оценок пока нет") }
        } else {
            items(state.stats.recentLessons) { item ->
                RecentMarkCard(subject = item.first, mark = item.second)
            }
        }
    }
}

@Composable
private fun GreetingCard(
    greeting: String,
    month: String,
    day: String,
    lessonCount: String
) {
    Card(
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.7f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(BlueSky),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "M",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = BlueDeep
                    )
                }
                Column(
                    modifier = Modifier
                        .padding(start = 10.dp)
                        .weight(1f)
                ) {
                    Text(
                        text = "Hello, Max",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "У тебя $lessonCount уроков",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Icon(
                    imageVector = Icons.Rounded.NotificationsNone,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp)
                )
            }

            Text(
                text = greeting,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = BlueDeep
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = month,
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = day,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        imageVector = Icons.Rounded.CalendarMonth,
                        contentDescription = null,
                        tint = BluePrimary,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "План",
                        style = MaterialTheme.typography.labelLarge,
                        color = BluePrimary
                    )
                }
            }
        }
    }
}

@Composable
private fun NextTaskCard(subject: String, subtitle: String, mark: String) {
    Card(
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        elevation = CardDefaults.cardElevation(defaultElevation = 10.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        listOf(
                            BluePrimary,
                            BlueSecondary
                        )
                    )
                )
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Next Task",
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.White.copy(alpha = 0.95f)
                )
                MarkPill(mark = mark, inverse = true)
            }
            Text(
                text = subject,
                style = MaterialTheme.typography.titleLarge,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.9f),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun SectionTitle(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = BlueDeep
        )
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun LessonTaskCard(subject: String, homework: String, mark: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.75f))
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Rounded.Alarm,
                    contentDescription = null,
                    tint = AccentWarning,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = subject,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .padding(start = 8.dp)
                        .weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                MarkPill(mark = mark)
            }
            Text(
                text = homework,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun RecentMarkCard(subject: String, mark: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.75f))
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Rounded.CheckCircle,
                contentDescription = null,
                tint = AccentSuccess,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = subject,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            MarkPill(mark = mark)
        }
    }
}

@Composable
private fun AttentionCard(subject: String, average: Double) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.75f))
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
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
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
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.75f))
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Rounded.Bookmarks,
                contentDescription = null,
                tint = BluePrimary,
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
private fun MarkPill(mark: String, inverse: Boolean = false) {
    val markInt = mark.toIntOrNull()
    val tint = when {
        markInt == null -> BlueSecondary
        markInt >= 9 -> AccentSuccess
        markInt >= 7 -> BluePrimary
        markInt >= 5 -> AccentWarning
        else -> AccentDanger
    }

    val bgColor = if (inverse) Color.White.copy(alpha = 0.2f) else tint.copy(alpha = 0.14f)
    val textColor = if (inverse) Color.White else tint

    Card(
        colors = CardDefaults.cardColors(containerColor = bgColor),
        shape = RoundedCornerShape(14.dp)
    ) {
        Text(
            text = mark,
            color = textColor,
            fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
        )
    }
}
