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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import by.schools.chetverka.ui.DiaryUiState
import by.schools.chetverka.ui.EmptyState
import by.schools.chetverka.ui.theme.AccentDanger
import by.schools.chetverka.ui.theme.AccentSuccess
import by.schools.chetverka.ui.theme.AccentWarning
import by.schools.chetverka.ui.theme.BlueDeep
import by.schools.chetverka.ui.theme.BluePrimary
import by.schools.chetverka.ui.theme.BlueSky
import by.schools.chetverka.ui.theme.CardWhite

@Composable
fun DiaryScreen(
    padding: PaddingValues,
    state: DiaryUiState,
    initialWeekIndex: Int
) {
    if (state.weeks.isEmpty() && state.isLoading) {
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

    if (state.weeks.isEmpty()) {
        EmptyState(
            title = "Дневник пуст",
            subtitle = "Сначала обнови данные после входа.",
            padding = padding
        )
        return
    }

    var selectedWeek by remember(state.weeks, initialWeekIndex) {
        mutableIntStateOf(initialWeekIndex.coerceIn(0, state.weeks.lastIndex))
    }
    val week = state.weeks[selectedWeek]

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(
            start = 0.dp,
            top = padding.calculateTopPadding() + 12.dp,
            end = 0.dp,
            bottom = padding.calculateBottomPadding() + 24.dp
        )
    ) {
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(28.dp),
                colors = CardDefaults.cardColors(containerColor = Color.Transparent)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.horizontalGradient(
                                colors = listOf(BluePrimary, BlueDeep)
                            )
                        )
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = { if (selectedWeek > 0) selectedWeek -= 1 },
                        enabled = selectedWeek > 0,
                        modifier = Modifier.background(Color.White.copy(alpha = 0.2f), CircleShape)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.ChevronLeft,
                            contentDescription = "Предыдущая неделя",
                            tint = Color.White
                        )
                    }
                    Text(
                        week.title(),
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                    IconButton(
                        onClick = { if (selectedWeek < state.weeks.lastIndex) selectedWeek += 1 },
                        enabled = selectedWeek < state.weeks.lastIndex,
                        modifier = Modifier.background(Color.White.copy(alpha = 0.2f), CircleShape)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.ChevronRight,
                            contentDescription = "Следующая неделя",
                            tint = Color.White
                        )
                    }
                }
            }
        }

        items(week.days) { day ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = CardWhite),
                border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.75f))
            ) {
                Column {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(BlueSky.copy(alpha = 0.65f))
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.MenuBook,
                            contentDescription = null,
                            tint = BluePrimary,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            day.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        day.lessons.forEachIndexed { index, lesson ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = lesson.subject,
                                        style = MaterialTheme.typography.bodyLarge,
                                        fontWeight = FontWeight.Medium
                                    )
                                    if (!lesson.hw.isNullOrBlank()) {
                                        Text(
                                            text = lesson.hw ?: "",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            modifier = Modifier.padding(top = 3.dp)
                                        )
                                    }
                                }
                                MarkBadge(mark = lesson.mark)
                            }
                            if (index != day.lessons.lastIndex) {
                                HorizontalDivider(
                                    color = BlueSky.copy(alpha = 0.7f),
                                    thickness = 1.dp
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MarkBadge(mark: String?) {
    val numeric = mark?.toIntOrNull()
    val color = when {
        numeric == null -> BluePrimary
        numeric >= 9 -> AccentSuccess
        numeric >= 7 -> BluePrimary
        numeric >= 5 -> AccentWarning
        else -> AccentDanger
    }
    Card(
        shape = CircleShape,
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.16f)),
        border = BorderStroke(1.dp, color.copy(alpha = 0.22f))
    ) {
        Text(
            text = mark ?: "—",
            color = color,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
        )
    }
}
