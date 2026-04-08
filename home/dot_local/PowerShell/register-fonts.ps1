# register-fonts.ps1 — Register .ttf fonts in Windows per-user font store (HKCU)
#
# Called from sync-nfs (bash). Not directly executable from WSL due to
# powershell.exe requiring Windows paths; invoke via:
#   powershell.exe -NoProfile -File "$(wslpath -w ~/.local/bin/register-fonts.ps1)" \
#       -FontDir "C:\path\to\fonts" -RegPath "HKCU:\...\Fonts"

param([string]$FontDir, [string]$RegPath)

Add-Type -AssemblyName System.Drawing

$fontFiles = Get-ChildItem -Path $FontDir -Filter "*.ttf"
$registered = 0

foreach ($file in $fontFiles) {
    $collection = New-Object System.Drawing.Text.PrivateFontCollection
    try {
        $collection.AddFontFile($file.FullName)
        $familyName = $collection.Families[0].Name

        # Derive style from filename heuristics
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $style = "Regular"
        if ($baseName -match "Bold(?:Italic)?|Italic|Light|Medium|SemiBold|ExtraLight|Thin|ExtraBold|Black|Retina") {
            $style = $Matches[0]
        }

        $displayName = "$familyName $style (TrueType)"
        $existingValue = Get-ItemProperty -Path $RegPath -Name $displayName -ErrorAction SilentlyContinue

        if (-not $existingValue -or ($existingValue.$displayName -ne $file.FullName)) {
            New-ItemProperty -Path $RegPath -Name $displayName -Value $file.FullName -PropertyType String -Force | Out-Null
            Write-Host "  REG: $displayName"
            $registered++
        }
    } catch {
        Write-Host "  WARN: Could not read $($file.Name): $_"
    } finally {
        $collection.Dispose()
    }
}

Write-Host ""
Write-Host "Registered $registered font entries."

# Broadcast WM_FONTCHANGE (async — won't block/crash calling apps)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class FontBroadcast {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public static void Notify() {
        PostMessage((IntPtr)0xFFFF, 0x001D, IntPtr.Zero, IntPtr.Zero);
    }
}
"@
[FontBroadcast]::Notify()
Write-Host "Broadcast WM_FONTCHANGE to running applications."
Write-Host "NOTE: Windows Terminal must be restarted to pick up new fonts."
