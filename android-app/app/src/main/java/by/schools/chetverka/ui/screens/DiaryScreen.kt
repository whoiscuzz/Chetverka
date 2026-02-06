package by.schools.chetverka.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import by.schools.chetverka.ui.DiaryUiState
import by.schools.chetverka.ui.EmptyState

@Composable
fun DiaryScreen(
    padding: PaddingValues,
    state: DiaryUiState,
    initialWeekIndex: Int
) {
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
            .padding(padding)
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Button(onClick = { if (selectedWeek > 0) selectedWeek -= 1 }, enabled = selectedWeek > 0) {
                    Text("←")
                }
                Text(week.title(), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 12.dp))
                Button(
                    onClick = { if (selectedWeek < state.weeks.lastIndex) selectedWeek += 1 },
                    enabled = selectedWeek < state.weeks.lastIndex
                ) {
                    Text("→")
                }
            }
        }

        items(week.days) { day ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Text(day.name, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(12.dp))
                day.lessons.forEach { lesson ->
                    Text(
                        text = "• ${lesson.subject}  ${lesson.mark ?: "—"}",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
                    )
                    if (!lesson.hw.isNullOrBlank()) {
                        Text(
                            text = "  ДЗ: ${lesson.hw}",
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 2.dp)
                        )
                    }
                }
            }
        }
    }
}
