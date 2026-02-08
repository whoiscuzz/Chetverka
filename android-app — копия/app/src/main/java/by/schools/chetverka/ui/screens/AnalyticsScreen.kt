package by.schools.chetverka.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
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
fun AnalyticsScreen(
    padding: PaddingValues,
    average: Double,
    results: List<Triple<String, Double, Int>>,
    loaded: Boolean
) {
    if (!loaded) {
        EmptyState(
            title = "Нет аналитики",
            subtitle = "Появится после загрузки дневника.",
            padding = padding
        )
        return
    }

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
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White)
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                CircularProgressIndicator(
                    progress = (average / 10f).toFloat().coerceIn(0f, 1f),
                    modifier = Modifier.size(74.dp),
                    strokeWidth = 8.dp,
                    color = BluePrimary,
                    trackColor = BluePrimary.copy(alpha = 0.15f)
                )
                Column {
                    Text(
                        text = "Средний балл",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "%.2f / 10".format(average),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = BluePrimary
                    )
                    Text(
                        text = statusText(average),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        Text(
            text = "Предметы по успеваемости",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 6.dp)
        )

        results.take(8).forEach { (subject, avg, count) ->
            SubjectProgressCard(subject = subject, average = avg, marksCount = count)
        }
    }
}

@Composable
private fun SubjectProgressCard(subject: String, average: Double, marksCount: Int) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White)
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    text = subject,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "%.2f".format(average),
                    style = MaterialTheme.typography.titleMedium,
                    color = gradeColor(average),
                    fontWeight = FontWeight.Bold
                )
            }
            Text(
                text = "Оценок: $marksCount",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            LinearProgressIndicator(
                progress = (average / 10f).toFloat().coerceIn(0f, 1f),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp),
                color = gradeColor(average),
                trackColor = gradeColor(average).copy(alpha = 0.14f)
            )
        }
    }
}

private fun statusText(average: Double): String {
    return when {
        average >= 8.5 -> "Отличная динамика"
        average >= 6.5 -> "Хорошо, можно выше"
        average > 0 -> "Нужен рывок"
        else -> "Пока без оценок"
    }
}

private fun gradeColor(average: Double): Color {
    return when {
        average >= 8.5 -> AccentSuccess
        average >= 6.5 -> BluePrimary
        average >= 5.0 -> AccentWarning
        else -> AccentDanger
    }
}
