package by.schools.chetverka.data.api

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt
import kotlinx.serialization.Serializable

@Serializable
data class LoginRequest(
    val username: String,
    val password: String
)

@Serializable
data class ProfileDto(
    val fullName: String,
    val className: String? = null,
    val avatarUrl: String? = null,
    val classTeacher: String? = null
)

@Serializable
data class LoginResponse(
    val sessionid: String,
    val pupilid: String,
    val profile: ProfileDto
)

@Serializable
data class ApiError(
    val detail: String? = null
)

@Serializable
data class DiaryResponse(
    val weeks: List<WeekDto> = emptyList()
)

@Serializable
data class WeekDto(
    val monday: String,
    val days: List<DayDto> = emptyList()
) {
    fun title(): String {
        return runCatching {
            val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
            val start = LocalDate.parse(monday, formatter)
            val end = start.plusDays(6)
            val dayFormat = DateTimeFormatter.ofPattern("d MMMM", Locale("ru"))
            "${start.dayOfMonth} – ${end.format(dayFormat)}"
        }.getOrElse { "Неизвестная неделя" }
    }
}

@Serializable
data class DayDto(
    val date: String,
    val name: String,
    val lessons: List<LessonDto> = emptyList()
)

@Serializable
data class LessonDto(
    val subject: String,
    val mark: String? = null,
    val hw: String? = null,
    val attachments: List<LessonAttachment>? = null
) {
    val safeSubject: String
        get() = subject.lowercase().trim()

    val markInt: Int?
        get() {
            val cleaned = mark?.trim().orEmpty()
            if (cleaned.isBlank()) return null
            if (cleaned.contains("/")) {
                val parts = cleaned.split("/")
                if (parts.size != 2) return null
                val first = parts[0].toDoubleOrNull() ?: return null
                val second = parts[1].toDoubleOrNull() ?: return null
                return ((first + second) / 2.0).roundToInt()
            }
            cleaned.toIntOrNull()?.let { return it }
            // Cases like "8 (к/р)", "9*", "7,5" etc.
            val normalized = cleaned.replace(',', '.')
            normalized.toDoubleOrNull()?.let { return it.roundToInt() }
            val firstNumber = Regex("""\d+([.,]\d+)?""").find(normalized)?.value ?: return null
            return firstNumber.replace(',', '.').toDoubleOrNull()?.roundToInt()
        }
}

@Serializable
data class LessonAttachment(
    val name: String,
    val url: String? = null,
    val type: String? = null
)

@Serializable
data class NewsItem(
    val id: Int,
    val title: String,
    val body: String,
    val created_at: String,
    val is_published: Boolean? = null,
    val author_name: String? = null
)

@Serializable
data class CreateNewsPayload(
    val title: String,
    val body: String,
    val is_published: Boolean,
    val author_name: String
)
