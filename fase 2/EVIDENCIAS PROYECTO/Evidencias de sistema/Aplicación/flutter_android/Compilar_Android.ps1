$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class RutaShortPath {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    private static extern uint GetShortPathName(string source, StringBuilder result, int length);
    public static string Get(string path) {
        var result = new StringBuilder(4096);
        return GetShortPathName(path, result, result.Capacity) > 0 ? result.ToString() : path;
    }
}
'@
$projectPath = [RutaShortPath]::Get($PSScriptRoot)
$bundledFlutter = Join-Path (Split-Path $PSScriptRoot) 'tmp/flutter-sdk/bin/flutter.bat'
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $bundledFlutter) { $flutterExe = [RutaShortPath]::Get($bundledFlutter) }
elseif ($flutterCommand) { $flutterExe = $flutterCommand.Source }
else { throw 'Instala el SDK oficial de Flutter antes de compilar.' }
$jdkPath = 'C:/Program Files/Android/Android Studio/jbr'
if (Test-Path -LiteralPath $jdkPath) { $env:JAVA_HOME = [RutaShortPath]::Get($jdkPath) }
$sdkPath = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
if (Test-Path -LiteralPath $sdkPath) { $env:ANDROID_HOME = [RutaShortPath]::Get($sdkPath) }
$pubPath = Join-Path $env:LOCALAPPDATA 'Pub/Cache'
if (Test-Path -LiteralPath $pubPath) { $env:PUB_CACHE = [RutaShortPath]::Get($pubPath) }
$javaTemp = Join-Path $PSScriptRoot '.dart_tool/java-tmp'
New-Item -ItemType Directory -Path $javaTemp -Force | Out-Null
$shortTemp = [RutaShortPath]::Get($javaTemp).Replace('\','/')
$env:JAVA_TOOL_OPTIONS = "-Djava.net.preferIPv4Stack=true -Djava.io.tmpdir=$shortTemp -Djdk.net.unixdomain.tmpdir=$shortTemp"
$sharedGradle = Join-Path (Split-Path $PSScriptRoot) 'tmp/gradle-cache'
if (Test-Path -LiteralPath $sharedGradle) { $env:GRADLE_USER_HOME = [RutaShortPath]::Get($sharedGradle) }
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
Set-Location -LiteralPath $projectPath
& $flutterExe pub get
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron preparar las dependencias.' }
& $flutterExe analyze
if ($LASTEXITCODE -ne 0) { throw 'Corrige el análisis antes de compilar.' }
& $flutterExe test
if ($LASTEXITCODE -ne 0) { throw 'Hay pruebas que requieren revisión.' }
New-Item -ItemType Directory -Path evidencias -Force | Out-Null
& $flutterExe build apk --debug 2>&1 | Tee-Object -FilePath evidencias/compilacion_apk.txt
if ($LASTEXITCODE -ne 0) { throw 'La compilación falló. Consulta evidencias/compilacion_apk.txt.' }
Write-Host 'APK disponible en build/app/outputs/flutter-apk/app-debug.apk'
