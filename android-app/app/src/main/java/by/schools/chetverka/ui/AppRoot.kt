package by.schools.chetverka.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Insights
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import by.schools.chetverka.data.api.ProfileDto
import by.schools.chetverka.ui.login.LoginScreen
import by.schools.chetverka.ui.screens.AnalyticsScreen
import by.schools.chetverka.ui.screens.DashboardScreen
import by.schools.chetverka.ui.screens.DiaryScreen
import by.schools.chetverka.ui.screens.ProfileScreen
import by.schools.chetverka.ui.screens.ResultsScreen
import by.schools.chetverka.ui.theme.BluePrimary
import by.schools.chetverka.ui.theme.BlueSoft
import by.schools.chetverka.ui.theme.BlueSky
import by.schools.chetverka.ui.theme.CardWhite

private enum class Tab(
    val title: String,
    val icon: ImageVector
) {
    Dashboard("Главная", Icons.Rounded.Home),
    Diary("Дневник", Icons.Rounded.CalendarMonth),
    Analytics("Аналитика", Icons.Rounded.Insights),
    Results("Итоги", Icons.Rounded.EmojiEvents),
    Profile("Профиль", Icons.Rounded.Person)
}

@Composable
fun AppRoot(viewModel: AppViewModel) {
    val appState by viewModel.appState.collectAsStateWithLifecycle()
    val diaryState by viewModel.diaryState.collectAsStateWithLifecycle()

    AppBackground {
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
                profile = appState.profile,
                onLogout = viewModel::logout
            )
        }
    }
}

@Composable
private fun MainTabs(
    viewModel: AppViewModel,
    diaryState: DiaryUiState,
    profile: ProfileDto?,
    onLogout: () -> Unit
) {
    var selectedTab by rememberSaveable { mutableStateOf(Tab.Dashboard) }

    Scaffold(
        containerColor = Color.Transparent,
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 10.dp)
            ) {
                Surface(
                    color = CardWhite.copy(alpha = 0.96f),
                    tonalElevation = 10.dp,
                    shadowElevation = 20.dp,
                    shape = RoundedCornerShape(34.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    NavigationBar(
                        containerColor = Color.Transparent,
                        tonalElevation = 0.dp,
                        modifier = Modifier.height(70.dp)
                    ) {
                        Tab.entries.forEach { tab ->
                            NavigationBarItem(
                                selected = selectedTab == tab,
                                onClick = { selectedTab = tab },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = BluePrimary,
                                    selectedTextColor = BluePrimary,
                                    indicatorColor = BlueSky.copy(alpha = 0.72f),
                                    unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                    unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                                ),
                                icon = {
                                    Icon(
                                        imageVector = tab.icon,
                                        contentDescription = tab.title,
                                        modifier = Modifier.size(22.dp)
                                    )
                                },
                                label = { Text(tab.title) }
                            )
                        }
                    }
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
                results = viewModel.results(),
                loaded = diaryState.isLoaded
            )
            Tab.Results -> ResultsScreen(
                padding = padding,
                results = viewModel.results(),
                loaded = diaryState.isLoaded
            )
            Tab.Profile -> ProfileScreen(
                padding = padding,
                profile = profile,
                onReload = viewModel::reloadDiary,
                onLogout = onLogout
            )
        }
    }
}

@Composable
private fun AppBackground(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color.White,
                        BlueSoft,
                        BlueSky.copy(alpha = 0.52f),
                        Color.White
                    )
                )
            )
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(BlueSky.copy(alpha = 0.55f), Color.Transparent),
                        center = Offset(180f, 80f),
                        radius = 1200f
                    )
                )
        )
        content()
    }
}

@Composable
private fun FullScreenLoader() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Card(
            shape = RoundedCornerShape(32.dp),
            colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = CardWhite)
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 26.dp, vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(34.dp),
                    strokeWidth = 3.dp
                )
                Text("Подготовка приложения…", style = MaterialTheme.typography.titleMedium)
            }
        }
    }
}

@Composable
fun EmptyState(
    title: String,
    subtitle: String,
    padding: PaddingValues
) {
    Box(
        modifier = Modifier
            .padding(padding)
            .fillMaxSize()
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Card(
            shape = RoundedCornerShape(30.dp),
            colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = CardWhite.copy(alpha = 0.97f))
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 26.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Card(
                    shape = CircleShape,
                    colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = BlueSky.copy(alpha = 0.75f))
                ) {
                    Text(
                        text = "☁️",
                        style = MaterialTheme.typography.displaySmall,
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp)
                    )
                }
                Text(
                    text = title,
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 10.dp)
                )
                Text(
                    text = subtitle,
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        }
    }
}

@Composable
fun ScreenTitle(
    title: String,
    subtitle: String? = null,
    padding: PaddingValues
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(padding)
            .padding(horizontal = 20.dp, vertical = 12.dp)
    ) {
        Text(text = title, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        if (!subtitle.isNullOrBlank()) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}
