package by.schools.chetverka.data.news

import by.schools.chetverka.BuildConfig
import by.schools.chetverka.data.api.CreateNewsPayload
import by.schools.chetverka.data.api.NewsItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

sealed class NewsServiceError(message: String) : Exception(message) {
    data object MissingConfig : NewsServiceError("Не настроен News API.")
    data object MissingAdminCredentials : NewsServiceError("Не настроены ADMIN_EMAIL и ADMIN_PASSWORD.")
    data object InvalidAdminCredentials : NewsServiceError("Неверные admin-логин/пароль.")
    data class Server(val status: Int, val messageBody: String) :
        NewsServiceError("Ошибка сервера ($status): $messageBody")
    data object InvalidResponse : NewsServiceError("Некорректный ответ сервера новостей.")
}

class NewsService(
    private val client: OkHttpClient = OkHttpClient()
) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun fetchPublished(): List<NewsItem> = withContext(Dispatchers.IO) {
        val baseUrl = baseUrlOrNull() ?: throw NewsServiceError.MissingConfig
        val apiKey = apiKeyOrNull() ?: throw NewsServiceError.MissingConfig
        val url = "$baseUrl/rest/v1/news?select=id,title,body,created_at,is_published,author_name,image_url&is_published=eq.true&order=created_at.desc"
        val request = Request.Builder()
            .url(url)
            .addHeader("Accept", "application/json")
            .addHeader("apikey", apiKey)
            .addHeader("Authorization", "Bearer $apiKey")
            .get()
            .build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw NewsServiceError.Server(response.code, body)
            }
            runCatching { json.decodeFromString<List<NewsItem>>(body) }
                .getOrElse { throw NewsServiceError.InvalidResponse }
        }
    }

    suspend fun publish(title: String, body: String, authorName: String, imageUrl: String?): NewsItem = withContext(Dispatchers.IO) {
        val baseUrl = baseUrlOrNull() ?: throw NewsServiceError.MissingConfig
        val apiKey = apiKeyOrNull() ?: throw NewsServiceError.MissingConfig
        val token = fetchAdminAccessToken()
        val payload = CreateNewsPayload(
            title = title,
            body = body,
            is_published = true,
            author_name = authorName,
            image_url = imageUrl
        )
        val request = Request.Builder()
            .url("$baseUrl/rest/v1/news")
            .addHeader("Content-Type", "application/json")
            .addHeader("Accept", "application/json")
            .addHeader("Prefer", "return=representation")
            .addHeader("apikey", apiKey)
            .addHeader("Authorization", "Bearer $token")
            .post(json.encodeToString(payload).toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).execute().use { response ->
            val responseBody = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                if (responseBody.lowercase().contains("invalid_credentials")) {
                    throw NewsServiceError.InvalidAdminCredentials
                }
                throw NewsServiceError.Server(response.code, responseBody)
            }
            runCatching {
                json.decodeFromString<List<NewsItem>>(responseBody).first()
            }.recoverCatching {
                json.decodeFromString<NewsItem>(responseBody)
            }.getOrElse { throw NewsServiceError.InvalidResponse }
        }
    }

    private fun baseUrlOrNull(): String? = BuildConfig.NEWS_API_BASE_URL.trim().ifEmpty { null }
    private fun apiKeyOrNull(): String? = BuildConfig.NEWS_API_KEY.trim().ifEmpty { null }
    private fun adminEmailOrNull(): String? = BuildConfig.ADMIN_EMAIL.trim().ifEmpty { null }
    private fun adminPasswordOrNull(): String? = BuildConfig.ADMIN_PASSWORD.trim().ifEmpty { null }

    private suspend fun fetchAdminAccessToken(): String = withContext(Dispatchers.IO) {
        val baseUrl = baseUrlOrNull() ?: throw NewsServiceError.MissingConfig
        val apiKey = apiKeyOrNull() ?: throw NewsServiceError.MissingConfig
        val email = adminEmailOrNull()
        val password = adminPasswordOrNull()
        if (email == null || password == null) {
            throw NewsServiceError.MissingAdminCredentials
        }

        @Serializable
        data class AuthRequest(val email: String, val password: String)

        @Serializable
        data class AuthPayload(val access_token: String)

        val payload = json.encodeToString(AuthRequest(email = email, password = password))
        val request = Request.Builder()
            .url("$baseUrl/auth/v1/token?grant_type=password")
            .addHeader("Content-Type", "application/json")
            .addHeader("Accept", "application/json")
            .addHeader("apikey", apiKey)
            .post(payload.toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).execute().use { response ->
            val responseBody = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                if (responseBody.lowercase().contains("invalid_credentials")) {
                    throw NewsServiceError.InvalidAdminCredentials
                }
                throw NewsServiceError.Server(response.code, responseBody)
            }

            runCatching { json.decodeFromString<AuthPayload>(responseBody).access_token }
                .getOrElse { throw NewsServiceError.InvalidResponse }
        }
    }
}
