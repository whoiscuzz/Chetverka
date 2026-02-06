package by.schools.chetverka.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import by.schools.chetverka.ui.EmptyState

@Composable
fun AnalyticsScreen(
    padding: PaddingValues,
    average: Double,
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
            .padding(padding)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Card(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "Средний балл: %.2f".format(average),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(16.dp)
            )
        }
        Text(
            text = "Детальные графики можно добавить следующим шагом (Compose Charts).",
            style = MaterialTheme.typography.bodyMedium
        )
    }
}
