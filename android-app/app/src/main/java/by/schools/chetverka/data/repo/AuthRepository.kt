package by.schools.chetverka.data.repo

import by.schools.chetverka.data.api.ApiService
import by.schools.chetverka.data.api.LoginRequest
import by.schools.chetverka.data.storage.SessionStorage
import retrofit2.HttpException

class AuthRepository(
    private val api: ApiService,
    private val sessionStorage: SessionStorage
) {

    suspend fun login(username: String, password: String): Result<Unit> {
        return runCatching {
            val response = api.login(LoginRequest(username = username, password = password))
            sessionStorage.saveSession(response.sessionid, response.pupilid)
            sessionStorage.saveProfile(response.profile)
            Unit
        }.recoverCatching { throwable ->
            throw mapError(throwable)
        }
    }

    private fun mapError(throwable: Throwable): Throwable {
        if (throwable is HttpException && throwable.code() == 401) {
            return IllegalStateException("Неверный логин или пароль.")
        }
        return IllegalStateException(throwable.message ?: "Ошибка авторизации.")
    }
}
