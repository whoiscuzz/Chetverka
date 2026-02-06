package by.schools.chetverka.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = BluePrimary,
    onPrimary = Color.White,
    primaryContainer = BlueSky,
    onPrimaryContainer = BlueDeep,
    secondary = BlueSecondary,
    onSecondary = Color.White,
    tertiary = BlueDeep,
    background = BlueSoft,
    onBackground = TextMain,
    surface = CardWhite,
    onSurface = TextMain,
    surfaceVariant = Color(0xFFEAF2FF),
    onSurfaceVariant = TextMuted,
    outline = BlueBorder,
    error = AccentDanger,
    onError = Color.White
)

private val DarkColors = darkColorScheme(
    primary = BlueSecondary,
    onPrimary = Color.White,
    background = Color(0xFF071324),
    onBackground = Color(0xFFEAF2FF),
    surface = Color(0xFF0E203A),
    onSurface = Color(0xFFEAF2FF),
    surfaceVariant = Color(0xFF173357),
    onSurfaceVariant = Color(0xFFBDD4FF),
    outline = Color(0xFF3A5C86),
    error = Color(0xFFFF7A7A),
    onError = Color.Black
)

@Composable
fun ChetverkaTheme(
    darkTheme: Boolean = false,
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = Typography(),
        content = content
    )
}
