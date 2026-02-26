package by.schools.chetverka.ui

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import by.schools.chetverka.data.api.LessonDto
import by.schools.chetverka.data.api.NewsItem
import by.schools.chetverka.data.api.ProfileDto
import by.schools.chetverka.data.api.WeekDto
import by.schools.chetverka.data.news.NewsService
import by.schools.chetverka.data.repo.AuthRepository
import by.schools.chetverka.data.repo.DiaryRepository
import by.schools.chetverka.data.schoolsby.SchoolsByWebClient
import by.schools.chetverka.data.storage.DiaryCache
import by.schools.chetverka.data.storage.SessionData
import by.schools.chetverka.data.storage.SessionStorage
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AppUiState(
    val isBootLoading: Boolean = true,
    val isAuthLoading: Boolean = false,
    val isAuthenticated: Boolean = false,
    val authError: String? = null,
    val profile: ProfileDto? = null
)

data class DashboardStats(
    val randomGreeting: String = "Привет 👋",
    val lessonsToday: String = "—",
    val homeworkToday: String = "—",
    val overallAverage: String = "—",
    val todayLessonsList: List<LessonDto> = emptyList(),
    val recentLessons: List<Pair<String, String>> = emptyList(),
    val subjectsForAttention: List<Pair<String, Double>> = emptyList()
)

data class DiaryUiState(
    val isLoading: Boolean = false,
    val isLoaded: Boolean = false,
    val error: String? = null,
    val weeks: List<WeekDto> = emptyList(),
    val stats: DashboardStats = DashboardStats()
)

data class NewsUiState(
    val isLoading: Boolean = false,
    val loadedOnce: Boolean = false,
    val error: String? = null,
    val items: List<NewsItem> = emptyList()
)

data class SubjectResultUi(
    val subject: String,
    val average: Double,
    val marksCount: Int,
    val marks: List<Int>
)

class AppViewModel(
    private val sessionStorage: SessionStorage,
    private val authRepository: AuthRepository,
    private val diaryRepository: DiaryRepository,
    private val cache: DiaryCache,
    private val schoolsByClient: SchoolsByWebClient,
    private val newsService: NewsService
) : ViewModel() {

    private val greetings = listOf(
        "Снова за учебу?",
        "Готов(а) к новым знаниям (и мемам)?",
        "Загружаем оценки... надеюсь, там не все плохо.",
        "Какие оценки мы получим сегодня?",
        "Смотрим дневник... одним глазком."
    )

    private val _appState = MutableStateFlow(AppUiState())
    val appState: StateFlow<AppUiState> = _appState.asStateFlow()

    private val _diaryState = MutableStateFlow(DiaryUiState())
    val diaryState: StateFlow<DiaryUiState> = _diaryState.asStateFlow()

    private val _newsState = MutableStateFlow(NewsUiState())
    val newsState: StateFlow<NewsUiState> = _newsState.asStateFlow()

    private var currentSession: SessionData? = null

    init {
        bootstrap()
    }

    fun login(username: String, password: String) {
        if (username.isBlank() || password.isBlank()) {
            _appState.update { it.copy(authError = "Логин и пароль не могут быть пустыми.") }
            return
        }

        viewModelScope.launch {
            _appState.update { it.copy(isAuthLoading = true, authError = null) }
            val result = authRepository.login(username.trim(), password)
            result.onSuccess {
                bootstrap()
            }.onFailure { error ->
                _appState.update {
                    it.copy(
                        isAuthLoading = false,
                        authError = error.message ?: "Ошибка входа."
                    )
                }
            }
        }
    }

    fun reloadDiary() {
        val session = currentSession ?: return
        if (_diaryState.value.isLoading) return
        viewModelScope.launch {
            _diaryState.update { it.copy(isLoading = true, error = null) }
            val result = diaryRepository.loadDiary(session.sessionId, session.pupilId)
            val weeks = result.diary?.weeks.orEmpty()

            _diaryState.update {
                it.copy(
                    isLoading = false,
                    isLoaded = weeks.isNotEmpty(),
                    error = result.errorMessage,
                    weeks = weeks,
                    stats = calculateStats(weeks)
                )
            }
        }
    }

    fun logout() {
        val pupilId = currentSession?.pupilId
        viewModelScope.launch {
            runCatching { schoolsByClient.clearSession() }
        }
        sessionStorage.clear()
        cache.clear(pupilId)
        currentSession = null
        _appState.value = AppUiState(
            isBootLoading = false,
            isAuthenticated = false
        )
        _diaryState.value = DiaryUiState()
        _newsState.value = NewsUiState()
    }

    fun loadNewsIfNeeded() {
        if (_newsState.value.loadedOnce || _newsState.value.isLoading) return
        reloadNews()
    }

    fun reloadNews() {
        if (_newsState.value.isLoading) return
        viewModelScope.launch {
            _newsState.update { it.copy(isLoading = true, error = null) }
            runCatching { newsService.fetchPublished() }
                .onSuccess { items ->
                    _newsState.update {
                        it.copy(
                            isLoading = false,
                            loadedOnce = true,
                            error = null,
                            items = items
                        )
                    }
                }
                .onFailure { error ->
                    _newsState.update {
                        it.copy(
                            isLoading = false,
                            loadedOnce = false,
                            error = error.message ?: "Не удалось загрузить новости."
                        )
                    }
                }
        }
    }

    fun publishNews(title: String, body: String, imageUrl: String?) {
        val author = "fimacuzz"
        viewModelScope.launch {
            _newsState.update { it.copy(isLoading = true, error = null) }
            runCatching {
                newsService.publish(
                    title = title,
                    body = body,
                    authorName = author,
                    imageUrl = imageUrl
                )
            }
                .onSuccess { created ->
                    _newsState.update {
                        it.copy(
                            isLoading = false,
                            loadedOnce = true,
                            error = null,
                            items = listOf(created) + it.items
                        )
                    }
                }
                .onFailure { error ->
                    _newsState.update {
                        it.copy(
                            isLoading = false,
                            error = error.message ?: "Не удалось опубликовать новость."
                        )
                    }
                }
        }
    }

    fun isCurrentUserAdmin(): Boolean {
        val profile = appState.value.profile
        val byName = profile?.fullName?.contains("admin", ignoreCase = true) == true
        val byPupil = currentSession?.pupilId == "1106490"
        return byName || byPupil
    }

    private fun bootstrap() {
        viewModelScope.launch {
            val session = sessionStorage.loadSession()
            currentSession = session

            if (session == null) {
                _appState.value = AppUiState(
                    isBootLoading = false,
                    isAuthenticated = false
                )
                _diaryState.value = DiaryUiState()
                return@launch
            }

            _appState.value = AppUiState(
                isBootLoading = false,
                isAuthLoading = false,
                isAuthenticated = true,
                profile = sessionStorage.loadProfile()
            )
            reloadDiary()
            loadNewsIfNeeded()
        }
    }

    private fun calculateStats(weeks: List<WeekDto>): DashboardStats {
        val allLessons = weeks.flatMap { week -> week.days.flatMap { day -> day.lessons } }
        val allMarks = allLessons.mapNotNull { it.markInt }
        val overallAverage = if (allMarks.isEmpty()) {
            "—"
        } else {
            "%.2f".format(allMarks.average())
        }

        val todayLessons = findTodayLessons(weeks)
        val lessonsToday = todayLessons.size.toString()
        val homeworkToday = todayLessons.count { !it.hw.isNullOrBlank() }.toString()

        val recent = allLessons
            .filter { !it.mark.isNullOrBlank() && it.markInt != null }
            .takeLast(4)
            .reversed()
            .map { lesson -> (lesson.subject.replaceFirstChar { it.uppercase() } to (lesson.mark ?: "—")) }

        val subjectAverages = allLessons
            .mapNotNull { lesson ->
                val mark = lesson.markInt ?: return@mapNotNull null
                lesson.safeSubject to mark
            }
            .groupBy({ it.first }, { it.second })
            .map { (subject, marks) -> subject.replaceFirstChar { it.uppercase() } to marks.average() }
            .filter { it.second < 6.5 }
            .sortedBy { it.second }
            .take(2)

        return DashboardStats(
            randomGreeting = greetings.random(),
            lessonsToday = lessonsToday,
            homeworkToday = homeworkToday,
            overallAverage = overallAverage,
            todayLessonsList = todayLessons,
            recentLessons = recent,
            subjectsForAttention = subjectAverages
        )
    }

    fun analyticsAverage(): Double {
        val marks = diaryState.value.weeks
            .flatMap { it.days }
            .flatMap { it.lessons }
            .mapNotNull { it.markInt }
        if (marks.isEmpty()) return 0.0
        return marks.average()
    }

    fun results(): List<SubjectResultUi> {
        return diaryState.value.weeks
            .flatMap { it.days }
            .flatMap { it.lessons }
            .mapNotNull { lesson ->
                val mark = lesson.markInt ?: return@mapNotNull null
                lesson.safeSubject to mark
            }
            .groupBy({ it.first }, { it.second })
            .map { (subject, marks) ->
                SubjectResultUi(
                    subject = subject.replaceFirstChar { it.uppercase() },
                    average = marks.average(),
                    marksCount = marks.size,
                    marks = marks
                )
            }
            .sortedByDescending { it.average }
    }

    fun currentWeekIndex(): Int {
        val today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"))
        return diaryState.value.weeks.indexOfFirst { week ->
            week.days.any { day -> day.date == today }
        }.let { if (it < 0) 0 else it }
    }

    private fun findTodayLessons(weeks: List<WeekDto>): List<LessonDto> {
        val today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"))
        return weeks.flatMap(WeekDto::days)
            .firstOrNull { it.date == today }
            ?.lessons
            .orEmpty()
    }

    companion object {
        fun provideFactory(context: Context): ViewModelProvider.Factory {
            return object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    val appContext = context.applicationContext
                    val sessionStorage = SessionStorage(appContext)
                    val cache = DiaryCache(appContext)
                    val client = SchoolsByWebClient(appContext)
                    return AppViewModel(
                        sessionStorage = sessionStorage,
                        authRepository = AuthRepository(client, sessionStorage),
                        diaryRepository = DiaryRepository(client, cache),
                        cache = cache,
                        schoolsByClient = client,
                        newsService = NewsService()
                    ) as T
                }
            }
        }
    }
}
