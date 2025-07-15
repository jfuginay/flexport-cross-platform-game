plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("kotlin-kapt")
}

android {
    namespace = "com.flexport.game"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.flexport.game"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isDebuggable = true
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = "17"
    }
    
    buildFeatures {
        compose = true
    }
    
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }
    
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    val composeVersion = "1.6.8"
    val coroutinesVersion = "1.7.3"
    val roomVersion = "2.6.1"
    val koinVersion = "3.5.6"

    // Core Android dependencies
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")
    implementation("androidx.activity:activity-compose:1.9.0")
    
    // Coroutines for ECS
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:$coroutinesVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$coroutinesVersion")
    
    // Compose dependencies
    implementation("androidx.compose.ui:ui:$composeVersion")
    implementation("androidx.compose.ui:ui-tooling-preview:$composeVersion")
    implementation("androidx.compose.material:material:$composeVersion")
    implementation("androidx.compose.material:material-icons-extended:$composeVersion")
    implementation("androidx.appcompat:appcompat:1.7.0")
    
    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.7")
    
    // ViewModel and lifecycle for map state management
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.3")
    
    // Math and OpenGL libraries for map rendering
    implementation("org.joml:joml:1.10.5")
    
    // JSON parsing for economic data and port information
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    implementation("com.squareup.moshi:moshi:1.15.0")
    implementation("com.squareup.moshi:moshi-kotlin:1.15.0")
    
    // Image loading for map textures and port icons
    implementation("io.coil-kt:coil-compose:2.6.0")
    
    // Enhanced Compose foundation for custom drawing and gestures
    implementation("androidx.compose.foundation:foundation:$composeVersion")
    
    // Data storage for game state
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    
    // Room Database for asset management
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    kapt("androidx.room:room-compiler:$roomVersion")
    
    // Dependency Injection with Koin for asset system
    implementation("io.insert-koin:koin-android:$koinVersion")
    implementation("io.insert-koin:koin-androidx-compose:$koinVersion")
    
    // Coroutines for async processing
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:$coroutinesVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$coroutinesVersion")
    
    // ViewModel and LiveData
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.3")
    implementation("androidx.lifecycle:lifecycle-livedata-ktx:2.8.3")
    
    // OpenGL and graphics - using Android framework OpenGL
    // Note: androidx.opengl:opengl:1.0.0 doesn't exist, using framework OpenGL ES instead
    
    // Collections for performance optimization
    implementation("androidx.collection:collection-ktx:1.4.0")
    
    // Gson for data serialization
    implementation("com.google.code.gson:gson:2.10.1")
    
    // Charts and graphics for economic visualization
    implementation("com.github.PhilJay:MPAndroidChart:v3.1.0")
    
    // Additional Material Design 3 components
    implementation("androidx.compose.material3:material3:1.2.1")
    
    // Date and time handling for economics
    implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.5.0")
    
    // Serialization for economic data
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    
    // Networking for multiplayer
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    implementation("com.squareup.retrofit2:converter-moshi:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("org.java-websocket:Java-WebSocket:1.5.4")
    
    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:$coroutinesVersion")
    testImplementation("androidx.room:room-testing:$roomVersion")
    testImplementation("io.insert-koin:koin-test:$koinVersion")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4:$composeVersion")
    debugImplementation("androidx.compose.ui:ui-tooling:$composeVersion")
    debugImplementation("androidx.compose.ui:ui-test-manifest:$composeVersion")
}