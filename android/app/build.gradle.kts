plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.project_application"

    // ✅ กำหนดเป็นตัวเลข ไม่อิง flutter.*
    compileSdk = 34                      // ใช้ 34 (หรือ 35 ถ้าคุณติดตั้งครบ)
    ndkVersion = "29.0.13846066"         // ← ใส่ให้ "ตรงกับชื่อโฟลเดอร์จริง" ใน .../Android/Sdk/ndk/
                                         // ถ้าโฟลเดอร์เป็น 29.0.13846066-rc3 ให้ใส่ "-rc3" ให้ตรง

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }

    defaultConfig {
        applicationId = "com.example.project_application"
        minSdk = flutter.minSdkVersion                      // Firebase Database ต้องอย่างน้อย 23
        targetSdk = 34                   // หรือ 35 ถ้าคุณมี
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
        packaging {
        resources {
            // เลือก .so ของ TFLite ถ้าเจอซ้ำหลายชุด ABI
            pickFirsts += listOf(
                "lib/**/libtensorflowlite_jni.so",
                "lib/**/libxnnpack_delegate.so",
                "lib/**/libnnapi_delegate.so"
            )
        }
        // (ถ้าต้องการ) เปิด legacy packaging ของ jni
        // jniLibs { useLegacyPackaging = true }
    }


    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter { source = "../.." }

