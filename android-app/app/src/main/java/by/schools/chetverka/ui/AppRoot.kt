package by.schools.chetverka.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import by.schools.chetverka.ui.login.LoginScreen
import by.schools.chetverka.ui.screens.AnalyticsScreen
import by.schools.chetverka.ui.screens.DashboardScreen
import by.schools.chetverka.ui.screens.DiaryScreen
import by.schools.chetverka.ui.screens.ProfileScreen
import by.schools.chetverka.ui.screens.ResultsScreen

private enum class Tab(val title: String) {
    Dashboard("Главная"),
    Diary("Дневник"),
    Analytics("Аналитика"),
    Results("Итоги"),
    Profile("Профиль")
}

@Composable
fun AppRoot(viewModel: AppViewModel) {
    val appState by viewModel.appState.collectAsStateWithLifecycle()
    val diaryState by viewModel.diaryState.collectAsStateWithLifecycle()

    when {
        appState.isBootLoading -> FullScreenLoader()
        !appState.isAuthenticated -> LoginScreen(
            isLoading = appState.isAuthLoading,
            errorMessage = appState.authError,
            onLogin = viewModel::login
        )
        else -> MainTabs(
            viewModel = viewModel,
            diaryState = diaryState,
            profileName = appState.profile?.fullName,
            onLogout = viewModel::logout
        )
    }
}

@Composable
private fun MainTabs(
    viewModel: AppViewModel,
    diaryState: DiaryUiState,
    profileName: String?,
    onLogout: () -> Unit
) {
    var selectedTab by rememberSaveable { mutableStateOf(Tab.Dashboard) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                Tab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        icon = { Text(tab.title.take(1)) },
                        label = { Text(tab.title) }
                    )
                }
            }
        }
    ) { padding ->
        when (selectedTab) {
            Tab.Dashboard -> DashboardScreen(padding = padding, state = diaryState)
            Tab.Diary -> DiaryScreen(
                padding = padding,
                state = diaryState,
                initialWeekIndex = viewModel.currentWeekIndex()
            )
            Tab.Analytics -> AnalyticsScreen(
                padding = padding,
                average = viewModel.analyticsAverage(),
                loaded = diaryState.isLoaded
            )
            Tab.Results -> ResultsScreen(
                padding = padding,
                results = viewModel.results(),
                loaded = diaryState.isLoaded
            )
            Tab.Profile -> ProfileScreen(
                padding = padding,
                profileName = profileName,
                onReload = viewModel::reloadDiary,
                onLogout = onLogout
            )
        }
    }
}

@Composable
private fun FullScreenLoader() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
fun EmptyState(
    title: String,
    subtitle: String,
    padding: PaddingValues
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(top = 8.dp)
        )
    }
}

@Composable
fun ScreenTitle(title: String, padding: PaddingValues) {
    Text(
        text = title,
        style = MaterialTheme.typography.headlineSmall,
        modifier = Modifier
            .fillMaxWidth()
            .padding(padding)
            .padding(horizontal = 16.dp, vertical = 12.dp)
    )
}
