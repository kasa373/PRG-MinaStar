# Builds data/ for MinaStar from the files in raw/ and public catalogs.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$raw = Join-Path $root 'raw'
$data = Join-Path $root 'data'
$placesDir = Join-Path $data 'places'
New-Item -ItemType Directory -Force -Path $raw, $data, $placesDir | Out-Null
$logPath = Join-Path $root 'build-log.txt'
function Log($m) {
  $line = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
  Add-Content -Path $logPath -Value $line -Encoding UTF8
  Write-Host $line
}
Set-Content -Path $logPath -Value 'build start' -Encoding UTF8

# --- stars to magnitude 8 ---
Log 'stars8'
$starText = [IO.File]::ReadAllText((Join-Path $raw 'stars.8.json'))
$rx = [regex]'"id":(\d+),"properties":\{"mag":([-0-9.]+),"bv":"([^"]*)"\},"geometry":\{"type":"Point","coordinates":\[([-0-9.]+),([-0-9.]+)\]\}'
$starHits = $rx.Matches($starText)
Log ("stars8 matches " + $starHits.Count)
if ($starHits.Count -lt 10000) { throw 'stars.8.json did not match the expected shape' }

$hipPos = @{}
$bw = New-Object IO.BinaryWriter ([IO.File]::Create((Join-Path $data 'stars8.bin')))
$kept = 0
foreach ($m in $starHits) {
  $hip = [int]$m.Groups[1].Value
  $mag = [double]$m.Groups[2].Value
  if ($mag -gt 8.05) { continue }
  $bvRaw = $m.Groups[3].Value
  $bv = 0.0
  if ($bvRaw.Length -gt 0) { $bv = [double]$bvRaw }
  $ra = [double]$m.Groups[4].Value
  $dec = [double]$m.Groups[5].Value
  if ($ra -lt 0) { $ra += 360 }
  if ($ra -ge 360) { $ra -= 360 }
  $raQ = [int]([math]::Round($ra / 360.0 * 65536.0) % 65536)
  if ($raQ -lt 0) { $raQ += 65536 }
  $deQ = [int]([math]::Round($dec / 90.0 * 32767.0))
  if ($deQ -gt 32767) { $deQ = 32767 }
  if ($deQ -lt -32767) { $deQ = -32767 }
  $magQ = [int]([math]::Round($mag * 10.0))
  $bvQ = [int]([math]::Round($bv * 20.0))
  if ($bvQ -gt 127) { $bvQ = 127 }
  if ($bvQ -lt -128) { $bvQ = -128 }
  $bw.Write([uint16]$raQ)
  $bw.Write([int16]$deQ)
  $bw.Write([sbyte]$magQ)
  $bw.Write([sbyte]$bvQ)
  $kept++
  $hipPos[$hip] = @{ ra = [math]::Round($ra, 4); dec = [math]::Round($dec, 4); mag = [math]::Round($mag, 2) }
}
$bw.Close()
Log ("stars8 kept " + $kept)

# --- constellation lines, Japanese names, bright star names ---
Log 'sky'
$cons = Get-Content (Join-Path $raw 'constellations.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$lines = Get-Content (Join-Path $raw 'constellations.lines.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$lineById = @{}
foreach ($f in $lines.features) { $lineById[$f.id] = $f }
$names = Get-Content (Join-Path $raw 'starnames.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$jaByEn = @{
  'Sirius' = 'シリウス'; 'Canopus' = 'カノープス'; 'Arcturus' = 'アークトゥルス'; 'Vega' = 'ベガ'
  'Capella' = 'カペラ'; 'Rigel' = 'リゲル'; 'Procyon' = 'プロキオン'; 'Achernar' = 'アケルナル'
  'Betelgeuse' = 'ベテルギウス'; 'Hadar' = 'ハダル'; 'Altair' = 'アルタイル'; 'Acrux' = 'アクルックス'
  'Aldebaran' = 'アルデバラン'; 'Antares' = 'アンタレス'; 'Spica' = 'スピカ'; 'Pollux' = 'ポルックス'
  'Fomalhaut' = 'フォーマルハウト'; 'Deneb' = 'デネブ'; 'Mimosa' = 'ミモザ'; 'Regulus' = 'レグルス'
  'Adhara' = 'アダラ'; 'Castor' = 'カストル'; 'Gacrux' = 'ガクルックス'; 'Bellatrix' = 'ベラトリックス'
  'Elnath' = 'エルナト'; 'Miaplacidus' = 'ミアプラキドゥス'; 'Alnilam' = 'アルニラム'; 'Alnair' = 'アルナイル'
  'Alnitak' = 'アルニタク'; 'Alioth' = 'アリオト'; 'Dubhe' = 'ドゥーベ'; 'Mirfak' = 'ミルファク'
  'Wezen' = 'ウェゼン'; 'Alkaid' = 'アルカイド'; 'Sargas' = 'サルガス'; 'Avior' = 'アヴィオール'
  'Menkalinan' = 'メンカリナン'; 'Atria' = 'アトリア'; 'Kaus Australis' = 'カウズ・アウストラリス'
  'Alhena' = 'アルヘナ'; 'Peacock' = 'ピーコック'; 'Polaris' = 'ポラリス'; 'Alphard' = 'アルファルド'
  'Algieba' = 'アルギエバ'; 'Hamal' = 'ハマル'; 'Diphda' = 'ディフダ'; 'Mizar' = 'ミザール'
  'Nunki' = 'ヌンキ'; 'Menkent' = 'メンケント'; 'Alpheratz' = 'アルフェラッツ'; 'Mirach' = 'ミラク'
  'Saiph' = 'サイフ'; 'Kochab' = 'コカブ'; 'Rasalhague' = 'ラス・アルハゲ'; 'Algol' = 'アルゴル'
  'Denebola' = 'デネボラ'; 'Alphecca' = 'アルフェッカ'; 'Schedar' = 'シェダル'; 'Caph' = 'カフ'
  'Rigil Kentaurus' = 'ケンタウルス'; 'Rigil Kent' = 'ケンタウルス'; 'Toliman' = 'トリマン'
}
$sb = New-Object Text.StringBuilder
[void]$sb.Append('{')
[void]$sb.Append('"constellations":[')
$firstC = $true
foreach ($f in $cons.features) {
  $id = $f.id
  if (-not $lineById.ContainsKey($id)) { continue }
  $ja = [string]$f.properties.ja
  if (-not $ja) { $ja = [string]$f.properties.en }
  $ja = $ja -replace '座$',''
  $rank = [int]$f.properties.rank
  $label = $f.geometry.coordinates
  $lra = [double]$label[0]
  $lde = [double]$label[1]
  if ($lra -lt 0) { $lra += 360 }
  if (-not $firstC) { [void]$sb.Append(',') }
  $firstC = $false
  [void]$sb.Append('{')
  [void]$sb.Append('"id":"'); [void]$sb.Append($id); [void]$sb.Append('"')
  [void]$sb.Append(',"name":"'); [void]$sb.Append($ja); [void]$sb.Append('"')
  [void]$sb.Append(',"rank":'); [void]$sb.Append($rank)
  [void]$sb.Append(',"label":['); [void]$sb.Append([math]::Round($lra, 3)); [void]$sb.Append(','); [void]$sb.Append([math]::Round($lde, 3)); [void]$sb.Append(']')
  [void]$sb.Append(',"lines":[')
  $firstL = $true
  foreach ($seg in $lineById[$id].geometry.coordinates) {
    if (-not $firstL) { [void]$sb.Append(',') }
    $firstL = $false
    [void]$sb.Append('[')
    $firstP = $true
    foreach ($p in $seg) {
      $pra = [double]$p[0]
      $pde = [double]$p[1]
      if ($pra -lt 0) { $pra += 360 }
      if ($pra -ge 360) { $pra -= 360 }
      if (-not $firstP) { [void]$sb.Append(',') }
      $firstP = $false
      [void]$sb.Append('['); [void]$sb.Append([math]::Round($pra, 3)); [void]$sb.Append(','); [void]$sb.Append([math]::Round($pde, 3)); [void]$sb.Append(']')
    }
    [void]$sb.Append(']')
  }
  [void]$sb.Append(']}')
}
[void]$sb.Append('],"stars":[')
$firstS = $true
$named = 0
foreach ($prop in $names.PSObject.Properties) {
  $en = [string]$prop.Value.name
  if (-not $en -or -not $jaByEn.ContainsKey($en)) { continue }
  $hip = [int]$prop.Name
  if (-not $hipPos.ContainsKey($hip)) { continue }
  $pos = $hipPos[$hip]
  if (-not $firstS) { [void]$sb.Append(',') }
  $firstS = $false
  [void]$sb.Append('{')
  [void]$sb.Append('"name":"'); [void]$sb.Append($jaByEn[$en]); [void]$sb.Append('"')
  [void]$sb.Append(',"ra":'); [void]$sb.Append($pos.ra)
  [void]$sb.Append(',"dec":'); [void]$sb.Append($pos.dec)
  [void]$sb.Append(',"mag":'); [void]$sb.Append($pos.mag)
  [void]$sb.Append('}')
  $named++
}
[void]$sb.Append(']}')
[IO.File]::WriteAllText((Join-Path $data 'sky.json'), $sb.ToString(), [Text.UTF8Encoding]::new($false))
Log ("named stars " + $named)

Copy-Item (Join-Path $raw 'ne_110m_land.geojson') (Join-Path $data 'land.geojson') -Force
Log 'land copied'

# --- Japanese towns, grouped to 大字・町丁目 ---
$csvPath = Join-Path $raw 'latest.csv'
if (-not (Test-Path $csvPath) -or (Get-Item $csvPath).Length -lt 1000000) {
  Log 'download places'
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/geolonia/japanese-addresses/master/data/latest.csv' -OutFile $csvPath -UseBasicParsing -TimeoutSec 300
}
Log 'places'
$utf8 = [Text.UTF8Encoding]::new($false)
$sr = New-Object IO.StreamReader($csvPath, $utf8)
$header = $sr.ReadLine()
$cols = $header.Split(',')
$idx = @{}
for ($i = 0; $i -lt $cols.Length; $i++) { $idx[$cols[$i].Trim('"')] = $i }
Log ("csv header " + $header.Substring(0, [Math]::Min(180, $header.Length)))
foreach ($need in @('都道府県コード','市区町村名','大字町丁目名','緯度','経度')) {
  if (-not $idx.ContainsKey($need)) { throw "missing column $need" }
}
$map = @{}
$rows = 0
while ($null -ne ($line = $sr.ReadLine())) {
  if ($line.Length -lt 5) { continue }
  $c = $line.Split(',')
  $rows++
  $code = $c[$idx['都道府県コード']].Trim().Trim('"').PadLeft(2, '0')
  $city = $c[$idx['市区町村名']].Trim().Trim('"')
  $town = $c[$idx['大字町丁目名']].Trim().Trim('"')
  $latS = $c[$idx['緯度']].Trim().Trim('"')
  $lonS = $c[$idx['経度']].Trim().Trim('"')
  if ($latS.Length -eq 0 -or $lonS.Length -eq 0) { continue }
  $lat = 0.0
  $lon = 0.0
  if (-not [double]::TryParse($latS, [ref]$lat)) { continue }
  if (-not [double]::TryParse($lonS, [ref]$lon)) { continue }
  $key = $code + '|' + $city + '|' + $town
  if ($map.ContainsKey($key)) {
    $e = $map[$key]
    $e.Lat += $lat
    $e.Lon += $lon
    $e.N += 1
  } else {
    $map[$key] = [pscustomobject]@{ Code = $code; City = $city; Town = $town; Lat = $lat; Lon = $lon; N = 1 }
  }
}
$sr.Close()
Log ("place rows " + $rows + " towns " + $map.Count)
$byPref = @{}
foreach ($e in $map.Values) {
  if (-not $byPref.ContainsKey($e.Code)) { $byPref[$e.Code] = New-Object Collections.Generic.List[object] }
  $byPref[$e.Code].Add($e)
}
foreach ($code in $byPref.Keys) {
  $list = $byPref[$code]
  $out = New-Object Text.StringBuilder
  [void]$out.Append('[')
  $first = $true
  foreach ($e in $list) {
    $lat = [math]::Round($e.Lat / $e.N, 5)
    $lon = [math]::Round($e.Lon / $e.N, 5)
    $city = ($e.City -replace '\\','\\' -replace '"','\"')
    $town = ($e.Town -replace '\\','\\' -replace '"','\"')
    if (-not $first) { [void]$out.Append(',') }
    $first = $false
    [void]$out.Append('["'); [void]$out.Append($city); [void]$out.Append('","'); [void]$out.Append($town)
    [void]$out.Append('",'); [void]$out.Append($lat); [void]$out.Append(','); [void]$out.Append($lon); [void]$out.Append(']')
  }
  [void]$out.Append(']')
  $path = Join-Path $placesDir ($code + '.json')
  [IO.File]::WriteAllText($path, $out.ToString(), $utf8)
  Log ("pref " + $code + " " + $list.Count)
}

# --- Tycho-2 stars fainter than mag 8, down to mag 11 ---
Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.IO.Compression;
public static class TychoConvert {
  public static int ConvertFile(string gzPath, string outPath, bool append) {
    int n = 0;
    var inv = CultureInfo.InvariantCulture;
    var mode = append ? FileMode.Append : FileMode.Create;
    using (var fs = File.OpenRead(gzPath))
    using (var gz = new GZipStream(fs, CompressionMode.Decompress))
    using (var sr = new StreamReader(gz))
    using (var outFs = new FileStream(outPath, mode, FileAccess.Write))
    using (var bw = new BinaryWriter(outFs)) {
      string line;
      while ((line = sr.ReadLine()) != null) {
        if (line.Length < 177) continue;
        string vt = line.Substring(123, 6).Trim();
        string bt = line.Substring(110, 6).Trim();
        double mag;
        if (vt.Length > 0) mag = double.Parse(vt, inv);
        else if (bt.Length > 0) mag = double.Parse(bt, inv);
        else continue;
        if (mag <= 8.0 || mag > 11.0) continue;
        double ra = double.Parse(line.Substring(152, 12).Trim(), inv);
        double de = double.Parse(line.Substring(165, 12).Trim(), inv);
        if (ra < 0) ra += 360.0;
        if (ra >= 360) ra -= 360.0;
        int raQ = (int)Math.Round(ra / 360.0 * 65536.0) % 65536;
        if (raQ < 0) raQ += 65536;
        int deQ = (int)Math.Round(de / 90.0 * 32767.0);
        if (deQ > 32767) deQ = 32767;
        if (deQ < -32767) deQ = -32767;
        int magQ = (int)Math.Round(mag * 10.0);
        if (magQ > 127) magQ = 127;
        if (magQ < -128) magQ = -128;
        bw.Write((ushort)raQ);
        bw.Write((short)deQ);
        bw.Write((sbyte)magQ);
        bw.Write((sbyte)0);
        n++;
      }
    }
    return n;
  }
  public static string Sample(string gzPath) {
    using (var fs = File.OpenRead(gzPath))
    using (var gz = new GZipStream(fs, CompressionMode.Decompress))
    using (var sr = new StreamReader(gz)) {
      string line = sr.ReadLine();
      if (line == null) return "empty";
      return "len=" + line.Length + " VT=[" + line.Substring(123, 6) + "] RA=[" + line.Substring(152, 12) + "] DE=[" + line.Substring(165, 12) + "]";
    }
  }
}
'@

$tychoDir = Join-Path $raw 'tycho'
New-Item -ItemType Directory -Force -Path $tychoDir | Out-Null
$out11 = Join-Path $data 'stars11.bin'
if (Test-Path $out11) { Remove-Item $out11 }
$total11 = 0
for ($i = 0; $i -le 19; $i++) {
  $name = 'tyc2.dat.{0:d2}.gz' -f $i
  $gz = Join-Path $tychoDir $name
  $good = $false
  if (Test-Path $gz) {
    $fs = [IO.File]::OpenRead($gz)
    $magic = New-Object byte[] 2
    [void]$fs.Read($magic, 0, 2)
    $fs.Close()
    $good = ($magic[0] -eq 0x1F -and $magic[1] -eq 0x8B -and (Get-Item $gz).Length -gt 100000)
  }
  if (-not $good) {
    $url = 'https://cdsarc.cds.unistra.fr/ftp/I/259/' + $name
    Log ("download " + $name)
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.UserAgent = 'PRG-MinaStar/1.0'
    $req.Timeout = 180000
    $req.ReadWriteTimeout = 180000
    $resp = $req.GetResponse()
    $inStream = $resp.GetResponseStream()
    $outStream = [IO.File]::Create($gz)
    $inStream.CopyTo($outStream)
    $outStream.Close()
    $inStream.Close()
    $resp.Close()
  }
  if ($i -eq 0) { Log ([TychoConvert]::Sample($gz)) }
  $n = [TychoConvert]::ConvertFile($gz, $out11, ($i -gt 0))
  $total11 += $n
  Log ("tycho $name $n")
}
Log ("stars11 total " + $total11)
Log 'done'
