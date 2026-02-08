package by.schools.chetverka.data.repo

import by.schools.chetverka.data.api.ApiService
import by.schools.chetverka.data.api.DiaryResponse
import by.schools.chetverka.data.storage.DiaryCache

data class DiaryLoadResult(
    val diary: DiaryResponse?,
    val errorMessage: String? = null
)

class DiaryRepository(
    private val api: ApiService,
    private val cache: DiaryCache
) {

    suspend fun loadDiary(sessionId: String, pupilId: String): DiaryLoadResult {
        val cached = cache.load(pupilId)

        return try {
            val fresh = api.loadDiary(sessionId = sessionId, pupilId = pupilId)
            cache.save(fresh, pupilId)
            DiaryLoadResult(diary = fresh)
        } catch (error: Throwable) {
            if (cached != null) {
                DiaryLoadResult(diary = cached, errorMessage = null)
            } else {
                DiaryLoadResult(
                    diary = null,
                    errorMessage = error.message ?: "Не удалось загрузить дневник."
                )
            }
        }
    }
}
