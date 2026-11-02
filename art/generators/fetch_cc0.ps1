# Descarga los sets CC0 de ambientCG y los deja con nombres estables.
# Uso: pwsh -File art/generators/fetch_cc0.ps1
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$target = Join-Path $root "textures\cc0"
$temp = Join-Path $env:TEMP "cc0tex"

$sets = @(
	@{ Id = "Bricks097"; Name = "brick_red" },
	@{ Id = "Bricks042"; Name = "brick_warm" },
	@{ Id = "Concrete034"; Name = "concrete" },
	@{ Id = "Asphalt012"; Name = "asphalt" }
)

New-Item -ItemType Directory -Force -Path $target | Out-Null
New-Item -ItemType Directory -Force -Path $temp | Out-Null

foreach ($set in $sets) {
	$zip = Join-Path $temp "$($set.Id).zip"
	$folder = Join-Path $temp $set.Id
	Write-Host "Descargando $($set.Id)..."
	Invoke-WebRequest -Uri "https://ambientcg.com/get?file=$($set.Id)_1K-JPG.zip" -OutFile $zip -UseBasicParsing
	Expand-Archive -Path $zip -DestinationPath $folder -Force

	# NormalGL: el canal G sin invertir, que es lo que espera Roblox.
	Copy-Item (Join-Path $folder "$($set.Id)_1K-JPG_Color.jpg") (Join-Path $target "$($set.Name)_color.jpg") -Force
	Copy-Item (Join-Path $folder "$($set.Id)_1K-JPG_NormalGL.jpg") (Join-Path $target "$($set.Name)_normal.jpg") -Force
	Copy-Item (Join-Path $folder "$($set.Id)_1K-JPG_Roughness.jpg") (Join-Path $target "$($set.Name)_roughness.jpg") -Force
	Write-Host "  listo: $($set.Name)"
}

Write-Host "`nTexturas en $target"
