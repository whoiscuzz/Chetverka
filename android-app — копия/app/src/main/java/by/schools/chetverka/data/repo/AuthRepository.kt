package by.schools.chetverka.data.repo

import by.schools.chetverka.data.api.ApiService
import by.schools.chetverka.data.api.LoginRequest
import by.schools.chetverka.data.storage.SessionStorage
import java.io.IOException
import kotlinx.coroutines.delay
import org.json.JSONObject
import retrofit2.HttpException

class AuthRepository(
    private val api: ApiService,
    private val sessionStorage: SessionStorage
) {

    suspend fun login(username: String, password: String): Result<Unit> {
        var lastError: Throwable? = null

        repeat(MAX_LOGIN_ATTEMPTS) { attempt ->
            val result = runCatching {
                val response = api.login(LoginRequest(username = username, password = password))
                sessionStorage.saveSession(response.sessionid, response.pupilid)
                sessionStorage.saveProfile(response.profile)
                Unit
            }

            if (result.isSuccess) return result

            val throwable = result.exceptionOrNull() ?: IllegalStateException("Ошибка авторизации.")
            if (!shouldRetry(throwable, attempt)) {
                return Result.failure(mapError(throwable))
            }

            lastError = throwable
            delay(RETRY_DELAYS_MS[attempt])
        }

        return Result.failure(mapError(lastError ?: IllegalStateException("Ошибка авторизации.")))
    }

    private fun shouldRetry(throwable: Throwable, attempt: Int): Boolean {
        if (attempt >= MAX_LOGIN_ATTEMPTS - 1) return false
        if (throwable is IOException) return true
        if (throwable is HttpException) {
            if (throwable.code() == 401) return true
            if (throwable.code() in 500..599) return true
        }
        return false
    }

    private fun mapError(throwable: Throwable): Throwable {
        if (throwable is IOException) {
            return IllegalStateException("Нет связи с API. Проверь, что сервер запущен и доступен.")
        }

        if (throwable is HttpException) {
            val detail = extractDetail(throwable)

            if (throwable.code() == 401) {
                return IllegalStateException(
                    "Вход не выполнен. Проверь логин/пароль. Если всё верно, это может быть временный сбой schools.by — попробуй ещё раз."
                )
            }

            if (throwable.code() == 504 || detail.contains("timeout", ignoreCase = true)) {
                return IllegalStateException(
                    "Таймаут при запросе к schools.by. Подожди немного и повтори вход."
                )
            }

            if (throwable.code() in 500..599) {
                return IllegalStateException(
                    detail.ifBlank { "Ошибка сервера при авторизации (${throwable.code()})." }
                )
            }
        }

        return IllegalStateException(throwable.message ?: "Ошибка авторизации.")
    }

    private fun extractDetail(throwable: HttpException): String {
        val errorBody = throwable.response()?.errorBody()?.string().orEmpty()
        if (errorBody.isBlank()) return ""
        return runCatching {
            JSONObject(errorBody).optString("detail").orEmpty()
        }.getOrDefault("")
    }

    private companion object {
        const val MAX_LOGIN_ATTEMPTS = 3
        val RETRY_DELAYS_MS = listOf(1200L, 2200L)
    }
}
