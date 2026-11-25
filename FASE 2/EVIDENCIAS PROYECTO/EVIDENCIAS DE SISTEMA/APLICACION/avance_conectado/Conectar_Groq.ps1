[CmdletBinding()]
param(
    [ValidateSet('Configurar', 'Validar', 'Demostrar')]
    [string]$Accion = 'Validar',
    [string]$Python = 'python',
    [string]$ServidorPglite
)

$ErrorActionPreference = 'Stop'
# Una ventana de PowerShell 5.1 iniciada desde PowerShell 7 puede heredar las rutas de módulos de la otra versión.
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1')
$credencial = Join-Path $PSScriptRoot '.env.groq.local'

if ($Accion -eq 'Configurar') {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $ventana = New-Object Windows.Forms.Form
    $ventana.Text = 'RutaAlerta | Conectar GroqCloud'
    $ventana.ClientSize = [Drawing.Size]::new(435, 136)
    $ventana.StartPosition = 'CenterScreen'
    $ventana.FormBorderStyle = 'FixedDialog'
    $ventana.MaximizeBox = $false
    $ventana.MinimizeBox = $false
    $ventana.TopMost = $true
    $ventana.Font = [Drawing.Font]::new('Segoe UI', 10)
    $etiqueta = New-Object Windows.Forms.Label
    $etiqueta.Text = 'Pega la nueva clave con Ctrl+V y haz clic en Guardar.'
    $etiqueta.AutoSize = $true
    $etiqueta.Location = [Drawing.Point]::new(16, 16)
    $campo = New-Object Windows.Forms.TextBox
    $campo.SetBounds(16, 48, 403, 28)
    $campo.UseSystemPasswordChar = $true
    $guardar = New-Object Windows.Forms.Button
    $guardar.Text = 'Guardar'
    $guardar.SetBounds(325, 91, 94, 29)
    $guardar.DialogResult = 'OK'
    $ventana.Controls.AddRange(@($etiqueta, $campo, $guardar))
    $ventana.AcceptButton = $guardar
    $ventana.ActiveControl = $campo

    try {
        if ($ventana.ShowDialog() -ne 'OK') { return }
        $texto = $campo.Text.Trim()
        $campo.Clear()
        if ($texto -notmatch '^gsk_[A-Za-z0-9_-]{20,}$') {
            [void][Windows.Forms.MessageBox]::Show($ventana, 'La clave parece incompleta. Copia la clave nueva desde GroqCloud y vuelve a abrir este cuadro.', 'Clave sin guardar')
            exit 1
        }
        $clave = ConvertTo-SecureString -String $texto -AsPlainText -Force
        try {
            ConvertFrom-SecureString -SecureString $clave | Set-Content -LiteralPath $credencial -Encoding ascii
        }
        finally {
            $clave.Dispose()
        }
        [void][Windows.Forms.MessageBox]::Show($ventana, 'Clave guardada y cifrada en este equipo.', 'RutaAlerta')
    }
    catch {
        [void][Windows.Forms.MessageBox]::Show($ventana, 'Windows no pudo guardar la clave en la carpeta de RutaAlerta.', 'Clave sin guardar')
        exit 1
    }
    finally {
        $campo.Clear()
        $texto = $null
        $ventana.Dispose()
    }
    return
}

if (-not $ServidorPglite) {
    $ServidorPglite = Join-Path $PSScriptRoot 'scripts/servidor_prueba_pglite.mjs'
}

$claveAnterior = $env:GROQ_API_KEY
try {
    if (-not $claveAnterior) {
        if (-not (Test-Path -LiteralPath $credencial -PathType Leaf)) {
            throw 'Falta guardar la clave de GroqCloud. Usa -Accion Configurar.'
        }
        $clave = Get-Content -LiteralPath $credencial | ConvertTo-SecureString
        $puntero = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($clave)
        try {
            $env:GROQ_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($puntero).Trim()
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($puntero)
            $clave.Dispose()
        }
    }

    $argumentos = @(
        (Join-Path $PSScriptRoot 'scripts/demostrar_alertas.py')
        '--servidor-pglite'
        $ServidorPglite
    )
    if ($Accion -eq 'Validar') { $argumentos += '--validar-groq' }
    & $Python @argumentos
    exit $LASTEXITCODE
}
finally {
    $env:GROQ_API_KEY = $claveAnterior
}
