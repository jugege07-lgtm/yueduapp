#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CI 用的 Android 工程补丁脚本：
  1) 在 AndroidManifest.xml 中补齐权限（后台/锁屏播放需要）；
  2) 注册 audio_service 的 Service + Receiver（锁屏媒体控制必须）；
  3) 把 minSdk 锁成 21（后台音频与 sherpa_onnx 的最低要求）；
  4) 覆盖应用图标（android_res/mipmap-* -> android/app/src/main/res/mipmap-*）；
  5) 设置应用显示名称为「阅读」，并移除自适应图标 XML 以强制使用 PNG。

由 GitHub Actions 在 `flutter create --platforms=android .` 之后调用，
不依赖任何第三方库（仅标准库）。
"""
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")


def patch_manifest():
    if not os.path.exists(MANIFEST):
        print("! manifest 不存在，跳过:", MANIFEST)
        return

    with open(MANIFEST, encoding="utf-8") as f:
        s = f.read()

    # 1) 权限
    perms = [
        "android.permission.INTERNET",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
        "android.permission.WAKE_LOCK",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.READ_EXTERNAL_STORAGE",
    ]
    for perm in perms:
        line = '<uses-permission android:name="%s" />' % perm
        if line not in s:
            s = s.replace("</manifest>", "    %s\n</manifest>" % line, 1)

    # 2) audio_service 的 Service + Receiver（锁屏控制必需）
    if "com.ryanheise.audioservice.AudioService" not in s:
        service = """        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:exported="true"
            android:foregroundServiceType="mediaPlayback">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </service>
        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>"""
        s = s.replace("</application>", service + "\n    </application>", 1)

    # 3) 应用显示名称改为「阅读】
    s = re.sub(r'android:label="[^"]*"', 'android:label="阅读"', s)
    if 'android:label="阅读"' not in s:
        # 若原本没有 label，在 <application 标签上加
        s = re.sub(
            r'<application',
            '<application\n        android:label="阅读"',
            s,
            count=1,
        )

    # 4) 确保 icon 指向 mipmap/ic_launcher
    if 'android:icon="@mipmap/ic_launcher"' not in s:
        s = re.sub(
            r'android:icon="@[^"]+"',
            'android:icon="@mipmap/ic_launcher"',
            s,
        )

    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(s)
    print("+ manifest patched")


def patch_gradle():
    """把 minSdk 锁成 21、compileSdk 提到 36（file_picker 等插件要求）。"""
    candidates = [
        os.path.join(ROOT, "android", "app", "build.gradle"),
        os.path.join(ROOT, "android", "app", "build.gradle.kts"),
    ]
    for g in candidates:
        if not os.path.exists(g):
            continue
        with open(g, encoding="utf-8") as f:
            c = f.read()
        # minSdk -> 21
        c = re.sub(r"minSdk\s*=\s*\d+", "minSdk = 21", c)
        c = re.sub(r"minSdkVersion\s+\d+", "minSdkVersion 21", c)
        # compileSdk -> 36（file_picker 8.x 的 AAR 要求 >= 36）
        c = re.sub(r"compileSdk\s*=\s*\d+", "compileSdk = 36", c)
        c = re.sub(r"compileSdkVersion\s*\d+", "compileSdkVersion 36", c)
        with open(g, "w", encoding="utf-8") as f:
            f.write(c)
        print("+ gradle patched (minSdk=21, compileSdk=36):", os.path.basename(g))


def patch_icon():
    """把仓库里预先生成的图标覆盖到 Android 工程，并删除自适应图标 XML 以强制使用 PNG。"""
    res_dir = os.path.join(ROOT, "android", "app", "src", "main", "res")
    src_res = os.path.join(ROOT, "android_res")
    if not os.path.isdir(src_res):
        print("! android_res 不存在，跳过图标替换")
        return

    # 复制各密度图标
    for folder in os.listdir(src_res):
        src_folder = os.path.join(src_res, folder)
        if not os.path.isdir(src_folder):
            continue
        dst_folder = os.path.join(res_dir, folder)
        os.makedirs(dst_folder, exist_ok=True)
        for name in os.listdir(src_folder):
            if not name.endswith(".png"):
                continue
            src_file = os.path.join(src_folder, name)
            dst_file = os.path.join(dst_folder, name)
            shutil.copy2(src_file, dst_file)
            print("+ icon copied:", dst_file)

    # 移除自适应图标 XML，避免 API 26+ 使用系统默认矢量图标
    anydpi = os.path.join(res_dir, "mipmap-anydpi-v26")
    if os.path.isdir(anydpi):
        shutil.rmtree(anydpi)
        print("+ removed adaptive icon XML:", anydpi)


def patch_root_gradle():
    """在 android/build.gradle.kts 末尾追加 subprojects 配置，
    强制所有 Android library 子项目（如 file_picker 等插件）compileSdk=36。

    file_picker 8.x 插件模块自带 compileSdk 34（硬编码），而
    flutter_plugin_android_lifecycle 要求 >= 36，光改 app 模块无效，
    必须让所有 library 子项目都提升。
    """
    root = os.path.join(ROOT, "android", "build.gradle.kts")
    if not os.path.exists(root):
        print("! 根 build.gradle.kts 不存在，跳过:", root)
        return
    with open(root, encoding="utf-8") as f:
        c = f.read()
    marker = "// patch_android: force compileSdk"
    if marker in c:
        print("+ root gradle already patched")
        return
    snippet = '''
// patch_android: force compileSdk
gradle.projectsEvaluated {
    gradle.rootProject.subprojects.forEach { p ->
        if (p.plugins.hasPlugin("com.android.library")) {
            val androidExt = p.extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val setter = androidExt.javaClass.getMethod(
                        "setCompileSdkVersion",
                        Int::class.javaPrimitiveType
                    )
                    setter.invoke(androidExt, 36)
                    println("patch_android: compileSdk=36 on " + p.name)
                } catch (e: Exception) {
                    println("patch_android: skip " + p.name + " (" + e.message + ")")
                }
            }
        }
    }
}
'''
    with open(root, "w", encoding="utf-8") as f:
        f.write(c.rstrip() + "\n" + snippet)
    print("+ root gradle patched (force compileSdk=36 on library subprojects)")


def patch_pubcache_plugins():
    """直接改写 pub-cache 里各 Flutter 插件模块的 build.gradle(.kts)，
    把所有 compileSdk < 36 的硬编码提升到 36。

    file_picker 8.x 等老插件自带 compileSdkVersion 34（硬编码），
    反射方式在它们身上无效，只能直接改文件。
    """
    pub = os.path.expanduser(os.path.join("~", ".pub-cache", "hosted", "pub.dev"))
    if not os.path.isdir(pub):
        print("! pub-cache 不存在，跳过插件 compileSdk 补丁:", pub)
        return
    patched = 0
    for entry in sorted(os.listdir(pub)):
        pkg_dir = os.path.join(pub, entry)
        if not os.path.isdir(pkg_dir):
            continue
        for rel in ("android/build.gradle", "android/build.gradle.kts"):
            gradle = os.path.join(pkg_dir, rel)
            if not os.path.exists(gradle):
                continue
            with open(gradle, encoding="utf-8", errors="ignore") as f:
                c = f.read()
            orig = c
            c = re.sub(
                r"compileSdkVersion\s+(\d+)",
                lambda m: "compileSdkVersion 36" if int(m.group(1)) < 36 else m.group(0),
                c,
            )
            c = re.sub(
                r"compileSdk\s*=\s*(\d+)",
                lambda m: "compileSdk = 36" if int(m.group(1)) < 36 else m.group(0),
                c,
            )
            if c != orig:
                with open(gradle, "w", encoding="utf-8") as f:
                    f.write(c)
                patched += 1
                print("+ plugin compileSdk patched:", os.path.join(entry, rel))
    print("+ pub-cache plugins patched count:", patched)


if __name__ == "__main__":
    patch_icon()
    patch_manifest()
    patch_gradle()
    patch_root_gradle()
    patch_pubcache_plugins()
    print("patch_android done")
