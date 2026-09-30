param(
  # Permet de lancer le build sans argument :
  #   powershell -ExecutionPolicy Bypass -File tool\build-web.ps1
  $EnvFile = "firebase\firebase.env.example",
  [switch]$Debug
)

# Charge le fichier de variables (une ligne KEY=VALUE par entree, # ignorees).
Get-Content $EnvFile | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  $parts = $line.Split('=', 2)
  if ($parts.Count -ne 2) { return }
  [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), 'Process')
}

$defines = @()
foreach ($name in @(
  'FIREBASE_API_KEY', 'FIREBASE_APP_ID', 'FIREBASE_MESSAGING_SENDER_ID',
  'FIREBASE_PROJECT_ID', 'FIREBASE_AUTH_DOMAIN', 'FIREBASE_STORAGE_BUCKET',
  'FIREBASE_MEASUREMENT_ID', 'FIREBASE_IOS_BUNDLE_ID', 'FIREBASE_WEB_CLIENT_ID')) {
  $value = [Environment]::GetEnvironmentVariable($name, 'Process')
  if ($value) { $defines += "--dart-define=$name=$value" }
}

if (-not $defines) {
  Write-Error "Aucune variable FIREBASE_* trouvee dans $EnvFile."
  exit 1
}

# Le defaut --base-href correspond au chemin de la Page GitHub ; changez-le
# dans la console GitHub (Settings > Pages) si le depot est renomme.
$baseHref = "/ball-ruler-game/"

if ($Debug) {
  flutter run -d chrome @defines
} else {
  flutter build web --release --base-href $baseHref @defines
}
