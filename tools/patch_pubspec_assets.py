#!/usr/bin/env python3
"""根据 assets/tts-model/ 下的实际目录结构，动态补全 pubspec.yaml 的 assets 条目。

Flutter 的目录 assets 只包含该目录下的直接文件，不包含子目录。
本脚本扫描 assets/tts-model/ 下的所有子目录，为每个子目录生成一条 assets 声明，
确保模型文件（如 dict/pos_dict/、espeak-ng-data/ 等）能被正确打包进 APK。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBSPEC = os.path.join(ROOT, 'pubspec.yaml')
ASSET_DIR = os.path.join(ROOT, 'assets', 'tts-model')


def main():
    if not os.path.isdir(ASSET_DIR):
        print(f'[patch_pubspec_assets] {ASSET_DIR} 不存在，跳过')
        return

    # 收集所有子目录（按深度排序，先父后子）
    asset_dir_rel = os.path.relpath(ASSET_DIR, ROOT)
    dirs = []
    for cur, subdirs, _ in os.walk(ASSET_DIR):
        rel = os.path.relpath(cur, ROOT)
        if rel != asset_dir_rel:
            dirs.append(rel)
    dirs.sort()

    # 探测 pubspec.yaml 中 assets 条目的缩进（通常 2 或 4 个空格）
    with open(PUBSPEC, 'r', encoding='utf-8') as f:
        content = f.read()
    indent_match = re.search(r'^(\s*)- assets/tts-model/', content, re.MULTILINE)
    indent = indent_match.group(1) if indent_match else '    '

    entries = [f'{indent}- assets/tts-model/']
    for d in dirs:
        entries.append(f'{indent}- {d}/')

    # 移除所有旧的 tts-model assets 条目（兼容不同缩进）
    content = re.sub(r'^\s*- assets/tts-model/.*\n', '', content, flags=re.MULTILINE)

    # 在 flutter: ... assets: 段落后插入新条目
    pattern = re.compile(r'^(flutter:[\s\S]*?\n\s*assets:\s*\n)', re.MULTILINE)
    if not pattern.search(content):
        print('[patch_pubspec_assets] 未找到 pubspec.yaml 中的 flutter: assets: 段落', file=sys.stderr)
        sys.exit(1)

    new_entries = '\n'.join(entries) + '\n'
    content = pattern.sub(r'\1' + new_entries, content)

    with open(PUBSPEC, 'w', encoding='utf-8') as f:
        f.write(content)

    print('[patch_pubspec_assets] 已更新 pubspec.yaml assets 条目：')
    for e in entries:
        print(f'  {e}')


if __name__ == '__main__':
    main()
