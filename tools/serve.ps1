$root = Split-Path -Parent $PSScriptRoot
$prefix = 'http://localhost:8765/'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "MinaStar $prefix"
$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.js' = 'text/javascript; charset=utf-8'
  '.css' = 'text/css; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.geojson' = 'application/json; charset=utf-8'
  '.bin' = 'application/octet-stream'
}
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
  if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'index.html' }
  $path = Join-Path $root ($rel -replace '/', '\')
  $full = [IO.Path]::GetFullPath($path)
  if (-not $full.StartsWith([IO.Path]::GetFullPath($root))) {
    $ctx.Response.StatusCode = 403
    $ctx.Response.Close()
    continue
  }
  if (-not (Test-Path $full -PathType Leaf)) {
    $ctx.Response.StatusCode = 404
    $bytes = [Text.Encoding]::UTF8.GetBytes('not found')
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
    continue
  }
  $ext = [IO.Path]::GetExtension($full).ToLowerInvariant()
  $ctx.Response.ContentType = $types[$ext]
  if (-not $ctx.Response.ContentType) { $ctx.Response.ContentType = 'application/octet-stream' }
  $ctx.Response.Headers['Cache-Control'] = 'no-cache'
  $data = [IO.File]::ReadAllBytes($full)
  $ctx.Response.ContentLength64 = $data.Length
  $ctx.Response.OutputStream.Write($data, 0, $data.Length)
  $ctx.Response.Close()
}
