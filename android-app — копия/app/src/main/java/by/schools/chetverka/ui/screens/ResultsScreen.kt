package by.schools.chetverka.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import by.schools.chetverka.ui.EmptyState
import by.schools.chetverka.ui.theme.AccentDanger
import by.schools.chetverka.ui.theme.AccentSuccess
import by.schools.chetverka.ui.theme.AccentWarning
import by.schools.chetverka.ui.theme.BluePrimary

@Composable
fun ResultsScreen(
    padding: PaddingValues,
    results: List<Triple<String, Double, Int>>,
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
            ResultsHeader(results = results)
        }
        itemsIndexed(results) { index, item ->
            ResultCard(
                position = index + 1,
                subject = item.first,
                average = item.second,
                marksCount = item.third
            )
        }
    }
}

@Composable
private fun ResultsHeader(results: List<Triple<String, Double, Int>>) {
    val totalMarks = results.sumOf { it.third }
    val weighted = if (totalMarks > 0) {
        results.sumOf { it.second * it.third } / totalMarks
    } else {
        0.0
    }
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
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
            }
        }
    }
}

@Composable
private fun ResultCard(
    position: Int,
    subject: String,
    average: Double,
    marksCount: Int
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White)
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            PositionBadge(position = position)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = subject,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "Оценок: $marksCount",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }
            Text(
                text = "%.2f".format(average),
                style = MaterialTheme.typography.titleLarge,
                color = statusColor(average),
                fontWeight = FontWeight.Bold
            )
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
        shape = RoundedCornerShape(10.dp),
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

private fun statusColor(average: Double): Color {
    return when {
        average >= 8.5 -> AccentSuccess
        average >= 6.5 -> BluePrimary
        average >= 5.0 -> AccentWarning
        else -> AccentDanger
    }
}
