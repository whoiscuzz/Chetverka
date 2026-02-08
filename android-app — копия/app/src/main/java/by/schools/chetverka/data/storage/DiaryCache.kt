package by.schools.chetverka.data.storage

import android.content.Context
import by.schools.chetverka.data.api.DiaryResponse
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

class DiaryCache(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }

    fun save(response: DiaryResponse, pupilId: String) {
        val file = fileFor(pupilId)
        file.writeText(json.encodeToString(response))
    }

    fun load(pupilId: String): DiaryResponse? {
        val file = fileFor(pupilId)
        if (!file.exists()) return null
        val raw = file.readText()
        return runCatching { json.decodeFromString<DiaryResponse>(raw) }.getOrNull()
    }

    fun clear(pupilId: String?) {
        if (pupilId.isNullOrBlank()) return
        fileFor(pupilId).delete()
    }

    private fun fileFor(pupilId: String): File {
        return File(context.filesDir, "diary_$pupilId.json")
    }
}
