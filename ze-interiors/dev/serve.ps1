# Dev only (not in files{}, never sent to players): serves the whole `resources` folder over http
# so dev/preview.html can load the NUI. Run it, then open
#   http://localhost:8765/%5Bletr%5D/ze-interiors/dev/preview.html
# Stop it with Ctrl+C.

param([int]$Port = 8765)

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$types = @{
    '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
    '.js' = 'application/javascript; charset=utf-8'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$Port/"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        try {
            $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/').Replace('/', '\')
            $path = Join-Path $root $rel
            # never serve anything outside the resources folder
            if ((Test-Path -LiteralPath $path -PathType Leaf) -and ((Resolve-Path -LiteralPath $path).Path.StartsWith($root))) {
                $bytes = [System.IO.File]::ReadAllBytes($path)
                $ext = [System.IO.Path]::GetExtension($path).ToLower()
                $ctx.Response.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' })
                $ctx.Response.Headers.Add('Cache-Control', 'no-store')
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $ctx.Response.StatusCode = 404
            }
        } catch {
            $ctx.Response.StatusCode = 500
        }
        $ctx.Response.Close()
    }
} finally {
    $listener.Stop()
}
