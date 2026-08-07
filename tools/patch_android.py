#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CI 用的 Android 工程补丁脚本：
  1) 在 AndroidManifest.xml 中补齐权限（后台/锁屏播放需要）；
  2) 注册 audio_service 的 Service + Receiver（锁屏媒体控制必须）；
  3) 把 minSdk 锁成 21（后台音频与 sherpa_onnx 的最低要求）。

由 GitHub Actions 在 `flutter create --platforms=android .` 之后调用，
不依赖任何第三方库（仅标准库）。
"""
import os
import re

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

    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(s)
    print("+ manifest patched")


def patch_minsdk():
    candidates = [
        os.path.join(ROOT, "android", "app", "build.gradle"),
        os.path.join(ROOT, "android", "app", "build.gradle.kts"),
    ]
    for g in candidates:
        if not os.path.exists(g):
            continue
        with open(g, encoding="utf-8") as f:
            c = f.read()
        c = re.sub(r"minSdk\s*=\s*\d+", "minSdk = 21", c)
        c = re.sub(r"minSdkVersion\s+\d+", "minSdkVersion 21", c)
        with open(g, "w", encoding="utf-8") as f:
            f.write(c)
        print("+ minSdk patched:", os.path.basename(g))


if __name__ == "__main__":
    patch_manifest()
    patch_minsdk()
    print("patch_android done")
