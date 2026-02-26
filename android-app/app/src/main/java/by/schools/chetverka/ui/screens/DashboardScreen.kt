package by.schools.chetverka.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Book
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.PlaylistAddCheck
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import by.schools.chetverka.data.api.LessonDto
import by.schools.chetverka.data.api.NewsItem
import by.schools.chetverka.ui.DiaryUiState
import by.schools.chetverka.ui.EmptyState
import by.schools.chetverka.ui.NewsUiState
import by.schools.chetverka.ui.theme.AccentDanger
import by.schools.chetverka.ui.theme.AccentSuccess
import by.schools.chetverka.ui.theme.AccentWarning
import by.schools.chetverka.ui.theme.BluePrimary
import by.schools.chetverka.ui.theme.BlueSky
import by.schools.chetverka.ui.theme.CardWhite
import by.schools.chetverka.ui.theme.BlueDeep
import coil.compose.AsyncImage
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterialApi::class)
@Composable
fun DashboardScreen(
    padding: PaddingValues,
    state: DiaryUiState,
    newsState: NewsUiState,
    onRefresh: () -> Unit,
    onNewsAll: () -> Unit,
    onNewsDetail: (NewsItem) -> Unit
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
            subtitle = state.error ?: "Зайди в профиль и нажми «Обновить дневник».",
            padding = padding
        )
        return
    }

    val isRefreshing = state.isLoading || newsState.isLoading
    val today = LocalDate.now()
    val todayFormatted = today.format(
        DateTimeFormatter.ofPattern("EEEE, d MMMM", Locale("ru"))
    ).replaceFirstChar { it.uppercase() }

    val pullRefreshState = rememberPullRefreshState(isRefreshing, onRefresh)
    Box(
        modifier = Modifier
            .fillMaxSize()
            .pullRefresh(pullRefreshState)
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(25.dp),
            contentPadding = PaddingValues(
                start = 0.dp,
                top = padding.calculateTopPadding() + 12.dp,
                end = 0.dp,
                bottom = padding.calculateBottomPadding() + 24.dp
            )
        ) {
            item {
                GreetingSection(
                    greeting = state.stats.randomGreeting,
                    today = todayFormatted
                )
            }
            item {
                NewsSection(
                    newsState = newsState,
                    onAllClick = onNewsAll,
                    onRefresh = onRefresh,
                    onItemClick = onNewsDetail
                )
            }
            item {
                StatCardsSection(
                    lessonsToday = state.stats.lessonsToday,
                    homeworkToday = state.stats.homeworkToday,
                    overallAverage = state.stats.overallAverage
                )
            }
            item {
                TodayLessonsSection(lessons = state.stats.todayLessonsList)
            }
            item {
                RecentMarksSection(recentLessons = state.stats.recentLessons)
            }
            item {
                AttentionSubjectsSection(
                    subjects = state.stats.subjectsForAttention
                )
            }
        }
        PullRefreshIndicator(
            refreshing = isRefreshing,
            state = pullRefreshState,
            modifier = Modifier.align(Alignment.TopCenter),
            contentColor = BluePrimary
        )
    }
}

@Composable
private fun GreetingSection(greeting: String, today: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = greeting,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = BlueDeep
        )
        Text(
            text = today,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun NewsSection(
    newsState: NewsUiState,
    onAllClick: () -> Unit,
    onRefresh: () -> Unit,
    onItemClick: (NewsItem) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Новости",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = BlueDeep
            )
            if (newsState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    text = "Все",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = BluePrimary,
                    modifier = Modifier
                        .clickable(onClick = onAllClick)
                        .padding(8.dp)
                )
            }
        }
        when {
            newsState.error != null -> ErrorNewsCard(
                title = "Не удалось загрузить новости",
                message = newsState.error!!,
                onRetry = onRefresh
            )
            newsState.items.isEmpty() && !newsState.isLoading -> PlaceholderCard(
                text = "Пока новостей нет.",
                icon = "📰"
            )
            newsState.items.isNotEmpty() -> {
                Text(
                    text = "Последняя новость",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                NewsCard(
                    item = newsState.items.first()!!,
                    onClick = { onItemClick(newsState.items.first()!!) }
                )
            }
        }
    }
}

@Composable
private fun ErrorNewsCard(title: String, message: String, onRetry: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = AccentDanger.copy(alpha = 0.08f))
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            OutlinedButton(onClick = onRetry) { Text("Повторить") }
        }
    }
}

@Composable
private fun NewsCard(item: NewsItem, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = item.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            if (!item.image_url.isNullOrBlank()) {
                AsyncImage(
                    model = item.image_url,
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(170.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop
                )
            }
            Text(
                text = item.body,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 4,
                overflow = TextOverflow.Ellipsis
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = formatNewsDate(item.created_at),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (!item.author_name.isNullOrBlank()) {
                    Text(
                        text = item.author_name,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Icon(
                    imageVector = Icons.Rounded.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                )
            }
        }
    }
}

private fun formatNewsDate(iso: String): String {
    return runCatching {
        val parsed = java.time.Instant.parse(iso)
        val formatter = DateTimeFormatter.ofPattern("d MMM", Locale("ru"))
        parsed.atZone(java.time.ZoneId.systemDefault()).format(formatter)
    }.getOrElse { iso }
}

@Composable
private fun StatCardsSection(
    lessonsToday: String,
    homeworkToday: String,
    overallAverage: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        StatCard(
            modifier = Modifier.weight(1f),
            title = "Уроков",
            value = lessonsToday,
            icon = Icons.Rounded.Book,
            color = AccentWarning
        )
        StatCard(
            modifier = Modifier.weight(1f),
            title = "ДЗ",
            value = homeworkToday,
            icon = Icons.Rounded.PlaylistAddCheck,
            color = Color(0xFF00BCD4)
        )
        StatCard(
            modifier = Modifier.weight(1f),
            title = "Средний балл",
            value = overallAverage,
            icon = Icons.Rounded.Star,
            color = Color(0xFFFFC107)
        )
    }
}

@Composable
private fun StatCard(
    modifier: Modifier = Modifier,
    title: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.1f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(24.dp)
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
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
private fun TodayLessonsSection(lessons: List<LessonDto>) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Уроки на сегодня",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = BlueDeep
        )
        if (lessons.isEmpty()) {
            PlaceholderCard(
                text = "Уроков нет, можно отдыхать!",
                icon = "😴"
            )
        } else {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    lessons.forEachIndexed { index, lesson ->
                        LessonRow(lesson = lesson)
                        if (index < lessons.lastIndex) {
                            androidx.compose.material3.HorizontalDivider(
                                modifier = Modifier.padding(vertical = 8.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LessonRow(lesson: LessonDto) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Icon(
            imageVector = Icons.Rounded.Book,
            contentDescription = null,
            tint = BluePrimary,
            modifier = Modifier.size(24.dp)
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = lesson.subject,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                lesson.markInt?.let { mark -> MarkBadge(mark = mark) }
            }
            lesson.hw?.takeIf { it.isNotBlank() }?.let { hw ->
                Text(
                    text = hw,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun MarkBadge(mark: Int) {
    val color = when {
        mark >= 9 -> AccentSuccess
        mark >= 7 -> BluePrimary
        mark >= 5 -> AccentWarning
        else -> AccentDanger
    }
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(BluePrimary),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = mark.toString(),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

@Composable
private fun RecentMarksSection(recentLessons: List<Pair<String, String>>) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Последние оценки",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = BlueDeep
        )
        if (recentLessons.isEmpty()) {
            PlaceholderCard(
                text = "Оценок пока нет. Время ставить рекорды!",
                icon = "✨"
            )
        } else {
            recentLessons.forEach { (subject, mark) ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(15.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(50.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(BluePrimary),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = mark,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = subject,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = "Оценка",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AttentionSubjectsSection(subjects: List<Pair<String, Double>>) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Требуют внимания",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = BlueDeep
        )
        if (subjects.isEmpty()) {
            PlaceholderCard(
                text = "Проблемных предметов нет. Так держать!",
                icon = "🏆"
            )
        } else {
            subjects.forEach { (subject, average) ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(AccentDanger.copy(alpha = 0.1f)),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Rounded.ErrorOutline,
                        contentDescription = null,
                        tint = AccentDanger,
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
                        fontWeight = FontWeight.Bold,
                        color = AccentDanger
                    )
                }
            }
        }
    }
}

@Composable
private fun PlaceholderCard(text: String, icon: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AccentSuccess.copy(alpha = 0.1f)),
        horizontalArrangement = Arrangement.spacedBy(15.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = icon, style = MaterialTheme.typography.headlineSmall)
        Text(
            text = text,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
