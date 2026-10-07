Add-Type -AssemblyName System.Drawing

function Save-Mark([int]$size, [string]$path, [double]$pad) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(255, 6, 9, 16))
    $scale = ($size * (1 - (2 * $pad))) / 64
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 75, 102, 216)), 7.4
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $points = @(
        [System.Drawing.PointF]::new(-12.0, -9.5),
        [System.Drawing.PointF]::new(0.0, -23.5),
        [System.Drawing.PointF]::new(12.0, -9.5)
    )
    $g.TranslateTransform($size / 2, $size / 2)
    $g.ScaleTransform($scale, $scale)
    for ($i = 0; $i -lt 5; $i++) {
        $state = $g.Save()
        $g.RotateTransform($i * 72)
        $g.DrawLines($pen, $points)
        $g.Restore($state)
    }
    $dir = Split-Path $path
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

$web = "D:\Others\Apps\mailclient\front_mailclient\web"
$res = "D:\Others\Apps\mailclient\front_mailclient\android\app\src\main\res"
Save-Mark 192 "$web\favicon.png" 0.12
Save-Mark 192 "$web\icons\Icon-192.png" 0.12
Save-Mark 512 "$web\icons\Icon-512.png" 0.12
Save-Mark 192 "$web\icons\Icon-maskable-192.png" 0.22
Save-Mark 512 "$web\icons\Icon-maskable-512.png" 0.22
Save-Mark 48 "$res\mipmap-mdpi\ic_launcher.png" 0.12
Save-Mark 72 "$res\mipmap-hdpi\ic_launcher.png" 0.12
Save-Mark 96 "$res\mipmap-xhdpi\ic_launcher.png" 0.12
Save-Mark 144 "$res\mipmap-xxhdpi\ic_launcher.png" 0.12
Save-Mark 192 "$res\mipmap-xxxhdpi\ic_launcher.png" 0.12
Write-Output "icons-ok"
