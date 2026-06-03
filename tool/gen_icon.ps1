Add-Type -AssemblyName System.Drawing

$size = 1024
$outDir = Join-Path $PSScriptRoot '..\assets\icon'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-RoundedPath($x, $y, $w, $h, $r) {
    $d = 2 * $r
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Draw-Glyph($g) {
    $blue  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(37, 99, 235))
    $gray  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(203, 213, 225))
    $green = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(34, 197, 94))

    # white card
    $card = New-RoundedPath 232 322 560 380 44
    $g.FillPath([System.Drawing.Brushes]::White, $card)

    # avatar circle
    $g.FillEllipse($blue, 300, 392, 120, 120)
    # name line + subtitle line
    $g.FillPath($blue, (New-RoundedPath 452 402 250 40 20))
    $g.FillPath($gray, (New-RoundedPath 452 462 180 28 14))
    # body lines
    $g.FillPath($gray, (New-RoundedPath 300 560 430 26 13))
    $g.FillPath($gray, (New-RoundedPath 300 606 320 26 13))

    # green "saved to contacts" check badge
    $g.FillEllipse($green, 690, 560, 150, 150)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 18
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $pts = @(
        (New-Object System.Drawing.Point 725, 635),
        (New-Object System.Drawing.Point 758, 670),
        (New-Object System.Drawing.Point 808, 598)
    )
    $g.DrawLines($pen, [System.Drawing.Point[]]$pts)
}

# ---- full opaque icon (iOS + legacy Android) ----
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(37, 99, 235),
    [System.Drawing.Color]::FromArgb(29, 78, 216),
    45.0)
$g.FillRectangle($grad, $rect)
Draw-Glyph $g
$g.Dispose()
$bmp.Save((Join-Path $outDir 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)

# ---- transparent foreground for Android adaptive icon (glyph scaled to ~62%) ----
$bmp2 = New-Object System.Drawing.Bitmap $size, $size
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g2.Clear([System.Drawing.Color]::Transparent)
$scale = 0.62
$g2.TranslateTransform([single]($size / 2), [single]($size / 2))
$g2.ScaleTransform([single]$scale, [single]$scale)
$g2.TranslateTransform([single](-$size / 2), [single](-$size / 2))
Draw-Glyph $g2
$g2.Dispose()
$bmp2.Save((Join-Path $outDir 'icon_foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png)

Write-Output 'icons written'
