package by.schools.chetverka.data.repo

import by.schools.chetverka.data.api.DiaryResponse
import by.schools.chetverka.data.schoolsby.SchoolsByWebClient
import by.schools.chetverka.data.storage.DiaryCache

data class DiaryLoadResult(
    val diary: DiaryResponse?,
    val errorMessage: String? = null
)

class DiaryRepository(
    private val client: SchoolsByWebClient,
    private val cache: DiaryCache
) {

    suspend fun loadDiary(sessionId: String, pupilId: String): DiaryLoadResult {
        val cached = cache.load(pupilId)

        return try {
            val fresh = client.fetchDiary(sessionId = sessionId, pupilId = pupilId)
            if (fresh.weeks.isEmpty()) {
                if (cached != null) {
                    return DiaryLoadResult(
                        diary = cached,
                        errorMessage = "Сервер вернул пустой дневник. Показан кэш."
                    )
                }
                return DiaryLoadResult(
                    diary = null,
                    errorMessage = "Дневник пустой или не распарсился. Попробуй обновить еще раз."
                )
            }
            cache.save(fresh, pupilId)
            DiaryLoadResult(diary = fresh)
        } catch (error: Throwable) {
            if (cached != null) {
                DiaryLoadResult(
                    diary = cached,
                    errorMessage = "Ошибка загрузки: ${error.message ?: "unknown"}. Показан кэш."
                )
            } else {
                DiaryLoadResult(
                    diary = null,
                    errorMessage = error.message ?: "Не удалось загрузить дневник."
                )
            }
        }
    }
}
