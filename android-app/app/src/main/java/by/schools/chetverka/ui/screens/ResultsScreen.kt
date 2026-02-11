package by.schools.chetverka.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import by.schools.chetverka.ui.EmptyState
import by.schools.chetverka.ui.SubjectResultUi
import by.schools.chetverka.ui.theme.AccentDanger
import by.schools.chetverka.ui.theme.AccentSuccess
import by.schools.chetverka.ui.theme.AccentWarning
import by.schools.chetverka.ui.theme.BluePrimary
import by.schools.chetverka.ui.theme.BlueSky
import by.schools.chetverka.ui.theme.CardWhite
import kotlin.math.roundToInt

@Composable
fun ResultsScreen(
    padding: PaddingValues,
    results: List<SubjectResultUi>,
    loaded: Boolean
) {
    if (!loaded) {
        EmptyState(
            title = "Нет итогов",
            subtitle = "Итоги появятся после загрузки оценок.",
            padding = padding
        )
        return
    }

    var selected by remember { mutableStateOf<SubjectResultUi?>(null) }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        state = rememberLazyListState(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(
            start = 0.dp,
            top = padding.calculateTopPadding() + 12.dp,
            end = 0.dp,
            bottom = padding.calculateBottomPadding() + 24.dp
        )
    ) {
        item {
            ResultsHeader(results = results)
        }
        itemsIndexed(results) { index, item ->
            ResultCard(
                position = index + 1,
                item = item,
                onOpenSimulation = { selected = item }
            )
        }
    }

    selected?.let { current ->
        SubjectSimulationDialog(
            item = current,
            onDismiss = { selected = null }
        )
    }
}

@Composable
private fun ResultsHeader(results: List<SubjectResultUi>) {
    val totalMarks = results.sumOf { it.marksCount }
    val weighted = if (totalMarks > 0) {
        results.sumOf { it.average * it.marksCount } / totalMarks
    } else {
        0.0
    }
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(30.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.75f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Rounded.EmojiEvents,
                contentDescription = null,
                tint = BluePrimary,
                modifier = Modifier.size(28.dp)
            )
            Column {
                Text("Итоги четверти", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(
                    text = "Общий средний: %.2f".format(weighted),
                    style = MaterialTheme.typography.headlineSmall,
                    color = BluePrimary,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Нажми на предмет, чтобы прикинуть итог.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun ResultCard(
    position: Int,
    item: SubjectResultUi,
    onOpenSimulation: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onOpenSimulation),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = CardWhite),
        border = BorderStroke(1.dp, BlueSky.copy(alpha = 0.7f))
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            PositionBadge(position = position)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.subject,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "Оценок: ${item.marksCount}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "%.2f".format(item.average),
                    style = MaterialTheme.typography.titleLarge,
                    color = statusColor(item.average),
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Прикинуть",
                    style = MaterialTheme.typography.labelSmall,
                    color = BluePrimary
                )
            }
        }
    }
}

@Composable
private fun SubjectSimulationDialog(
    item: SubjectResultUi,
    onDismiss: () -> Unit
) {
    val addedMarks = remember(item.subject) { mutableStateListOf<Int>() }
    var targetGrade by rememberSaveable(item.subject) { mutableIntStateOf(0) }

    val allMarks = remember(item.marks, addedMarks.size) { item.marks + addedMarks.toList() }
    val average = if (allMarks.isEmpty()) 0.0 else allMarks.average()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = CardWhite),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(item.subject, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        Text(
                            text = "Средний: %.2f (округл. ${average.roundToInt()})".format(average),
                            style = MaterialTheme.typography.bodyMedium,
                            color = statusColor(average)
                        )
                    }
                    IconButton(onClick = onDismiss) {
                        Icon(imageVector = Icons.Rounded.Close, contentDescription = "Закрыть")
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatPill(title = "Исходных", value = item.marks.size.toString(), modifier = Modifier.weight(1f))
                    StatPill(title = "Добавлено", value = addedMarks.size.toString(), modifier = Modifier.weight(1f))
                    StatPill(title = "Всего", value = allMarks.size.toString(), modifier = Modifier.weight(1f))
                }

                Text("Цель", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    TargetButton(label = "—", selected = targetGrade == 0, onClick = { targetGrade = 0 }, modifier = Modifier.weight(1f))
                    TargetButton(label = "10", selected = targetGrade == 10, onClick = { targetGrade = 10 }, modifier = Modifier.weight(1f))
                    TargetButton(label = "9", selected = targetGrade == 9, onClick = { targetGrade = 9 }, modifier = Modifier.weight(1f))
                    TargetButton(label = "8", selected = targetGrade == 8, onClick = { targetGrade = 8 }, modifier = Modifier.weight(1f))
                    TargetButton(label = "7", selected = targetGrade == 7, onClick = { targetGrade = 7 }, modifier = Modifier.weight(1f))
                }

                goalSummary(targetGrade = targetGrade, marks = allMarks)?.let { summary ->
                    Text(
                        text = summary,
                        style = MaterialTheme.typography.bodySmall,
                        color = BluePrimary,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                Text("Добавить оценку", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                MarksRow(marks = listOf(10, 9, 8, 7, 6)) { addedMarks += it }
                MarksRow(marks = listOf(5, 4, 3, 2, 1)) { addedMarks += it }

                if (addedMarks.isEmpty()) {
                    Text(
                        text = "Пока ничего не добавлено.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    LazyColumn(
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(120.dp)
                    ) {
                        itemsIndexed(addedMarks) { index, mark ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("Добавлено: $mark", color = statusColor(mark.toDouble()), fontWeight = FontWeight.SemiBold)
                                OutlinedButton(onClick = { addedMarks.removeAt(index) }) {
                                    Text("Удалить")
                                }
                            }
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        OutlinedButton(
                            onClick = { if (addedMarks.isNotEmpty()) addedMarks.removeAt(addedMarks.lastIndex) },
                            modifier = Modifier.weight(1f)
                        ) { Text("Удалить последнюю") }
                        FilledTonalButton(
                            onClick = { addedMarks.clear() },
                            modifier = Modifier.weight(1f)
                        ) { Text("Очистить все") }
                    }
                }
            }
        }
    }
}

@Composable
private fun MarksRow(
    marks: List<Int>,
    onAdd: (Int) -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
        marks.forEach { mark ->
            FilledTonalButton(onClick = { onAdd(mark) }, modifier = Modifier.weight(1f)) {
                Text(mark.toString(), fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun TargetButton(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (selected) {
        FilledTonalButton(onClick = onClick, modifier = modifier) {
            Text(label, fontWeight = FontWeight.Bold)
        }
    } else {
        OutlinedButton(onClick = onClick, modifier = modifier) {
            Text(label)
        }
    }
}

@Composable
private fun StatPill(title: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = BlueSky.copy(alpha = 0.25f)),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            modifier = Modifier.padding(vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun PositionBadge(position: Int) {
    val color = when (position) {
        1 -> Color(0xFFF5C542)
        2 -> Color(0xFFB7C2D6)
        3 -> Color(0xFFC78956)
        else -> BluePrimary.copy(alpha = 0.6f)
    }
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.15f))
    ) {
        Text(
            text = "#$position",
            color = color,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
        )
    }
}

private fun goalSummary(targetGrade: Int, marks: List<Int>): String? {
    if (targetGrade <= 0) return null
    if (marks.isEmpty()) return "Нужно начать с оценок по предмету."

    val roundedCurrent = marks.average().roundToInt()
    if (roundedCurrent >= targetGrade) return null

    val temp = marks.toMutableList()
    for (i in 1..100) {
        temp += 10
        if (temp.average().roundToInt() >= targetGrade) {
            val suffix = when {
                i == 1 -> "десятка"
                i in 2..4 -> "десятки"
                else -> "десяток"
            }
            return "Нужно еще $i $suffix"
        }
    }
    return "Цель кажется недостижимой"
}

private fun statusColor(average: Double): Color {
    return when {
        average >= 8.5 -> AccentSuccess
        average >= 6.5 -> BluePrimary
        average >= 5.0 -> AccentWarning
        else -> AccentDanger
    }
}
