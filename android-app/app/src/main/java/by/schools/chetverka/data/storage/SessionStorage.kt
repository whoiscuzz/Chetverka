package by.schools.chetverka.data.storage

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import by.schools.chetverka.data.api.ProfileDto
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

data class SessionData(
    val sessionId: String,
    val pupilId: String
)

class SessionStorage(context: Context) {

    private val json = Json { ignoreUnknownKeys = true }

    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        context,
        "chetverka_secure_storage",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveSession(sessionId: String, pupilId: String) {
        prefs.edit()
            .putString(KEY_SESSION_ID, sessionId)
            .putString(KEY_PUPIL_ID, pupilId)
            .apply()
    }

    fun loadSession(): SessionData? {
        val sessionId = prefs.getString(KEY_SESSION_ID, null)
        val pupilId = prefs.getString(KEY_PUPIL_ID, null)
        if (sessionId.isNullOrBlank() || pupilId.isNullOrBlank()) return null
        return SessionData(sessionId, pupilId)
    }

    fun saveProfile(profile: ProfileDto) {
        prefs.edit().putString(KEY_PROFILE, json.encodeToString(profile)).apply()
    }

    fun loadProfile(): ProfileDto? {
        val raw = prefs.getString(KEY_PROFILE, null) ?: return null
        return runCatching { json.decodeFromString<ProfileDto>(raw) }.getOrNull()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    private companion object {
        const val KEY_SESSION_ID = "sessionid"
        const val KEY_PUPIL_ID = "pupilid"
        const val KEY_PROFILE = "userProfile"
    }
}
