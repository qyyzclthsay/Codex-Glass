# Render documentation from the real WPF controls, using demo values only.
# Run with Windows PowerShell -STA after scripts/build-native.ps1.
param([switch]$TokensOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms,System.Drawing
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $root 'dist/native/Codex Glass.exe'))
$flags = [Reflection.BindingFlags]'Instance,Public,NonPublic'
$serviceType = $assembly.GetType('CodexGlass.Service')
$windowType = $assembly.GetType('CodexGlass.GlassWindow')
$ringType = $assembly.GetType('CodexGlass.RingView')
$demoDirectory = Join-Path $root '.qa/docs-demo-profile'
$service = $serviceType.GetConstructors($flags)[0].Invoke([object[]]@([string]$demoDirectory,$true))
$window = $windowType.GetConstructors($flags)[0].Invoke([object[]]@($service,$true))
$settings = $serviceType.GetField('Settings').GetValue($service)
$settings['theme'] = 'light'
$settings['accentColor'] = '#4c8df3'
$settings['elapsedArc'] = $true
$settings['ringWindow'] = 'five'
$settings['startup'] = $false

function Capture-Control($element, [double]$width, [string]$name) {
    $hostBorder = New-Object Windows.Controls.Border
    $hostBorder.Width = $width
    $hostBorder.Padding = [Windows.Thickness]::new(16)
    $hostBorder.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#F1F6FD')
    $hostBorder.Resources = $window.Resources
    $hostBorder.Language = $window.Language
    [Windows.Documents.TextElement]::SetFontFamily($hostBorder,$window.FontFamily)
    $hostBorder.Child = $element
    $hostBorder.Measure([Windows.Size]::new($width,[double]::PositiveInfinity))
    $size = $hostBorder.DesiredSize
    $hostBorder.Arrange([Windows.Rect]::new(0,0,$width,$size.Height))
    $hostBorder.UpdateLayout()
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new([int]($width*2),[int][Math]::Ceiling($size.Height*2),192,192,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($hostBorder)
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create((Join-Path $root "assets/$name.png"))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    $hostBorder.Child = $null
}

function New-DemoRing([string]$color,[bool]$outer) {
    $ring = [Activator]::CreateInstance($ringType,$true)
    $quota = New-Object 'Collections.Generic.Dictionary[string,object]'
    $quota['remaining'] = [double]75
    $quota['minutes'] = [double]300
    $quota['resetsAt'] = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+3*60*60*1000
    foreach ($pair in @{Quota=$quota;Period=$period;Accent=[Windows.Media.BrushConverter]::new().ConvertFromString($color);OuterAccent=[Windows.Media.BrushConverter]::new().ConvertFromString($color);Outer=$outer;Demo=$true;Logo=$windowType.GetField('logo',$flags).GetValue($window)}.GetEnumerator()) {
        $ringType.GetField($pair.Key).SetValue($ring,$pair.Value)
    }
    $ringType.GetMethod('Reveal').Invoke($ring,[object[]]@($true,$false)) | Out-Null
    return $ring
}

if (!$TokensOnly) { foreach ($locale in @('en','zh','zh-TW')) {
    $settings['language'] = $locale
    $windowType.GetMethod('Colors',$flags).Invoke($window,@()) | Out-Null
    $panel = $windowType.GetMethod('SettingsView',$flags).Invoke($window,@())
    $colorCard = $panel.Children[3]
    $ringCard = $panel.Children[5]
    $panel.Children.Remove($colorCard)
    $panel.Children.Remove($ringCard)
    Capture-Control $colorCard 354 "guide-color-$locale"
    Capture-Control $ringCard 354 "guide-ring-settings-$locale"
    $period = if ($locale -eq 'en') { '5 hours' } else { '5 小時' }
    if ($locale -eq 'zh') { $period = '5 小时' }
    $demo = New-Object Windows.Controls.StackPanel
    $demo.Orientation = 'Horizontal'
    $demo.HorizontalAlignment = 'Center'
    foreach ($color in @('#4c8df3','#8b5cf6','#16a085')) {
        $ring = New-DemoRing $color $true
        $ring.Margin = [Windows.Thickness]::new(6,4,6,4)
        $demo.Children.Add($ring) | Out-Null
    }
    Capture-Control $demo 354 "guide-color-rings-$locale"
    $comparison = New-Object Windows.Controls.StackPanel
    $comparison.Orientation = 'Horizontal'
    $comparison.HorizontalAlignment = 'Center'
    $labels = if ($locale -eq 'en') { @('Outer ring off','Outer ring on') } elseif ($locale -eq 'zh') { @('外环关闭','外环开启') } else { @('外環關閉','外環開啟') }
    for ($i=0;$i -lt 2;$i++) {
        $column = New-Object Windows.Controls.StackPanel
        $column.Width = 156
        $ring = New-DemoRing '#4c8df3' ($i -eq 1)
        $ring.HorizontalAlignment = 'Center'
        $column.Children.Add($ring) | Out-Null
        $label = New-Object Windows.Controls.TextBlock
        $label.Text = $labels[$i]
        $label.FontSize = 12
        $label.Margin = [Windows.Thickness]::new(0,10,0,0)
        $label.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#1E2D45')
        $label.HorizontalAlignment = 'Center'
        $column.Children.Add($label) | Out-Null
        $comparison.Children.Add($column) | Out-Null
    }
    Capture-Control $comparison 354 "guide-ring-$locale"
} }

# Artificial daily buckets: 78,743,291 in seven days and 133,268,538 in thirty.
# Do not load an account, credentials or real usage when producing public images.
$weights = @(0,2,3,5,1,0,4,7,2,1,3,6,0,4,2,8,1,0,2,5,3,1,4)
$weightTotal = ($weights | Measure-Object -Sum).Sum
$prior = @($weights | ForEach-Object { [Math]::Floor(54525247 * $_ / $weightTotal) })
$prior[22] += 54525247 - ($prior | Measure-Object -Sum).Sum
$values = $prior + @(3200000,5400000,9000000,7400000,11858696,10000000,31884595)
$records = @(for ($i=0;$i -lt 30;$i++) {
    @{date=[DateTime]::Today.AddDays($i-29).ToString('yyyy-MM-dd');tokens=[double]$values[$i]}
})
$json = @{days=$records;incomplete=$false} | ConvertTo-Json -Depth 5 -Compress
$daily = $assembly.GetType('CodexGlass.J').GetMethod('Parse').Invoke($null,[object[]]@([string]$json))
$serviceType.GetField('Daily').SetValue($service,$daily)
foreach ($locale in @('en','zh','zh-TW')) { foreach ($count in @(7,30)) {
    $settings['language'] = $locale
    $windowType.GetMethod('Colors',$flags).Invoke($window,@()) | Out-Null
    $windowType.GetField('range',$flags).SetValue($window,$count)
    $content = $windowType.GetMethod('DailyView',$flags).Invoke($window,@())
    $chart = $content.Children[2]
    $chart.GetType().GetField('tipIndex',$flags).SetValue($chart,($count-1))
    $label = New-Object Windows.Controls.TextBlock
    $label.Text = if ($locale -eq 'en') { 'DEMO · Artificial sample data' } elseif ($locale -eq 'zh') { 'DEMO · 虚构演示数据' } else { 'DEMO · 虛構示範資料' }
    $label.FontSize = 10
    $label.Margin = [Windows.Thickness]::new(0,8,0,0)
    $label.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#758398')
    $content.Children.Add($label) | Out-Null
    Capture-Control $content 354 "guide-tokens-$locale-$count"
} }
$windowType.GetField('closing',$flags).SetValue($window,$true)
$window.Close()
$serviceType.GetMethod('Dispose').Invoke($service,@()) | Out-Null
'Rendered documentation images using demo data only.'
