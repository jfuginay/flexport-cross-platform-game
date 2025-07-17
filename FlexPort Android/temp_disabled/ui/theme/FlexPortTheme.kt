package com.flexport.game.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

// FlexPort brand colors
private val FlexPortBlue = Color(0xFF1976D2)
private val FlexPortOcean = Color(0xFF0277BD)
private val FlexPortSky = Color(0xFF03A9F4)
private val FlexPortDeep = Color(0xFF0D47A1)

// Light theme colors
private val LightColorScheme = lightColorScheme(
    primary = FlexPortBlue,
    onPrimary = Color.White,
    primaryContainer = FlexPortSky.copy(alpha = 0.1f),
    onPrimaryContainer = FlexPortDeep,
    secondary = FlexPortOcean,
    onSecondary = Color.White,
    secondaryContainer = FlexPortOcean.copy(alpha = 0.1f),
    onSecondaryContainer = FlexPortDeep,
    tertiary = Color(0xFF2E7D32),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFF4CAF50).copy(alpha = 0.1f),
    onTertiaryContainer = Color(0xFF1B5E20),
    error = Color(0xFFD32F2F),
    onError = Color.White,
    errorContainer = Color(0xFFFFEBEE),
    onErrorContainer = Color(0xFFB71C1C),
    background = Color(0xFFFAFAFA),
    onBackground = Color(0xFF1A1A1A),
    surface = Color.White,
    onSurface = Color(0xFF1A1A1A),
    surfaceVariant = Color(0xFFF5F5F5),
    onSurfaceVariant = Color(0xFF666666),
    outline = Color(0xFFBDBDBD),
    outlineVariant = Color(0xFFE0E0E0)
)

// Dark theme colors
private val DarkColorScheme = darkColorScheme(
    primary = FlexPortSky,
    onPrimary = Color(0xFF002171),
    primaryContainer = FlexPortBlue.copy(alpha = 0.3f),
    onPrimaryContainer = FlexPortSky.copy(alpha = 0.9f),
    secondary = FlexPortOcean.copy(alpha = 0.8f),
    onSecondary = Color(0xFF001B3D),
    secondaryContainer = FlexPortOcean.copy(alpha = 0.2f),
    onSecondaryContainer = FlexPortOcean.copy(alpha = 0.9f),
    tertiary = Color(0xFF66BB6A),
    onTertiary = Color(0xFF003300),
    tertiaryContainer = Color(0xFF2E7D32).copy(alpha = 0.3f),
    onTertiaryContainer = Color(0xFF81C784),
    error = Color(0xFFEF5350),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFFB71C1C).copy(alpha = 0.3f),
    onErrorContainer = Color(0xFFFFCDD2),
    background = Color(0xFF0F1419),
    onBackground = Color(0xFFE1E2E1),
    surface = Color(0xFF1A1C1E),
    onSurface = Color(0xFFE1E2E1),
    surfaceVariant = Color(0xFF2D3135),
    onSurfaceVariant = Color(0xFFC1C7CE),
    outline = Color(0xFF8B9297),
    outlineVariant = Color(0xFF41474D)
)

@Composable
fun FlexPortTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    // Dynamic color is available on Android 12+
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }
    
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.primary.toArgb()
            window.navigationBarColor = colorScheme.surface.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
            WindowCompat.getInsetsController(window, view).isAppearanceLightNavigationBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = FlexPortTypography,
        shapes = FlexPortShapes,
        content = content
    )
}