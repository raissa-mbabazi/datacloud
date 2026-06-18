param(
  [int]$Port = 4173,
  [string]$Root = $PSScriptRoot
)

$mimeTypes = @{
  '.html' = 'text/html; charset=utf-8'
  '.htm'  = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.mjs'  = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.svg'  = 'image/svg+xml'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.webp' = 'image/webp'
  '.ico'  = 'image/x-icon'
  '.txt'  = 'text/plain; charset=utf-8'
}

function Get-MimeType {
  param([string]$Path)

  $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ($mimeTypes.ContainsKey($extension)) {
    return $mimeTypes[$extension]
  }

  return 'application/octet-stream'
}

$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
  $listener.Start()
  Write-Host "Serving $Root at $prefix"
  Start-Process $prefix

  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $requestPath = $context.Request.Url.AbsolutePath

    if ([string]::IsNullOrWhiteSpace($requestPath) -or $requestPath -eq '/') {
      $requestPath = '/index.html'
    }

    $relativePath = $requestPath.TrimStart('/') -replace '/', '\\'
    $filePath = Join-Path $Root $relativePath
    $response = $context.Response

    try {
      if (Test-Path $filePath -PathType Leaf) {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $response.ContentType = Get-MimeType -Path $filePath
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
      } else {
        $response.StatusCode = 404
        $message = [System.Text.Encoding]::UTF8.GetBytes('Not found')
        $response.ContentType = 'text/plain; charset=utf-8'
        $response.ContentLength64 = $message.Length
        $response.OutputStream.Write($message, 0, $message.Length)
      }
    } catch {
      $response.StatusCode = 500
      $message = [System.Text.Encoding]::UTF8.GetBytes('Server error')
      $response.ContentType = 'text/plain; charset=utf-8'
      $response.ContentLength64 = $message.Length
      $response.OutputStream.Write($message, 0, $message.Length)
    } finally {
      $response.OutputStream.Close()
    }
  }
} finally {
  if ($listener.IsListening) {
    $listener.Stop()
  }

  $listener.Close()
}