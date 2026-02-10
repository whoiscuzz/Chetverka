package by.schools.chetverka.data.repo

import by.schools.chetverka.data.schoolsby.SchoolsByWebClient
import by.schools.chetverka.data.storage.SessionStorage
import java.io.IOException
import kotlinx.coroutines.delay

class AuthRepository(
    private val client: SchoolsByWebClient,
    private val sessionStorage: SessionStorage
) {

    suspend fun login(username: String, password: String): Result<Unit> {
        var lastError: Throwable? = null

        repeat(MAX_LOGIN_ATTEMPTS) { attempt ->
            val result = runCatching {
                val response = client.login(username = username, password = password)
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
        return false
    }

    private fun mapError(throwable: Throwable): Throwable {
        if (throwable is IOException) {
            return IllegalStateException("Нет связи с интернетом. Проверь соединение и повтори вход.")
        }

        return IllegalStateException(throwable.message ?: "Ошибка авторизации.")
    }

    private companion object {
        const val MAX_LOGIN_ATTEMPTS = 3
        val RETRY_DELAYS_MS = listOf(1200L, 2200L)
    }
}
