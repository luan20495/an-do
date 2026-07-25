from pathlib import Path
root=Path(__file__).resolve().parents[1]
required=['pubspec.yaml','lib/main.dart','lib/features/map/presentation/map_screen.dart','android/app/src/main/AndroidManifest.xml','test/widget_smoke_test.dart']
missing=[x for x in required if not (root/x).exists()]
assert not missing, f'Missing: {missing}'
text='\n'.join(p.read_text(errors='ignore') for p in root.rglob('*') if p.is_file() and p.suffix in {'.dart','.kt','.xml','.yaml','.md'})
runtime='\n'.join(p.read_text(errors='ignore') for p in (root/'lib').rglob('*.dart'))
assert 'webview_flutter' not in runtime and 'WebView(' not in runtime
assert 'com.hoangluan.safetymap' in text
assert 'ACCESS_BACKGROUND_LOCATION' not in (root/'android/app/src/main/AndroidManifest.xml').read_text()
assert 'FOREGROUND_SERVICE_LOCATION' in text
print('REPOSITORY_STRUCTURE_OK')
