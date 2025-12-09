<#
.SYNOPSIS
    Sistema PRO de geração de hashes com configuração avançada
.VERSION
    3.0
#>

# Configurações globais padrão
$global:Config = @{
    HashAlgorithm = "SHA256"
    SaltSize = 32
    HashSize = 32
    MinHashSize = 16
    MaxHashSize = 128
    PBKDF2Iterations = 100000
    MinIterations = 10000
    MaxIterations = 1000000
    Argon2MemoryCost = 65536
    Argon2Parallelism = 4
    OutputFormat = "Hexadecimal" # Hexadecimal, Base64, Base64URL
    AutoCopyToClipboard = $true
    ShowDetails = $true
}

function Show-MainMenu {
    param (
        [string]$Title = 'SISTEMA ANOITECER - GERADOR PRO'
    )
    Clear-Host
    Write-Host "==================== $Title ====================" -ForegroundColor Cyan
    Write-Host " 1. Gerar Hash Rápido (Algoritmo: $($global:Config.HashAlgorithm))"
    Write-Host " 2. Gerar Hash com Salt Personalizado"
    Write-Host " 3. Gerar Hash PBKDF2 (Iterações: $($global:Config.PBKDF2Iterations))"
    Write-Host " 4. Gerar Hash Argon2 (Configurável)"
    Write-Host " 5. Configurações Avançadas"
    Write-Host " 6. Sobre o Sistema"
    Write-Host " Q. Sair" -ForegroundColor Red
    Write-Host "`nSelecione uma opção e pressione Enter" -ForegroundColor Yellow
}

function Show-ConfigMenu {
    Clear-Host
    Write-Host "============ CONFIGURAÇÕES AVANÇADAS ============" -ForegroundColor Cyan
    Write-Host " 1. Algoritmo Principal: $($global:Config.HashAlgorithm)"
    Write-Host " 2. Tamanho do Salt: $($global:Config.SaltSize) bytes"
    Write-Host " 3. Tamanho do Hash: $($global:Config.HashSize) bytes"
    Write-Host " 4. Iterações PBKDF2: $($global:Config.PBKDF2Iterations)"
    Write-Host " 5. Configurações Argon2"
    Write-Host " 6. Formato de Saída: $($global:Config.OutputFormat)"
    Write-Host " 7. Copiar automaticamente: $($global:Config.AutoCopyToClipboard)"
    Write-Host " 8. Mostrar detalhes: $($global:Config.ShowDetails)"
    Write-Host " 9. Restaurar Padrões"
    Write-Host " R. Voltar ao Menu Principal" -ForegroundColor Yellow
    Write-Host " Q. Sair" -ForegroundColor Red
}

function Get-Hash {
    param (
        [string]$InputString,
        [string]$Algorithm = "SHA256",
        [int]$Length = 32,
        [byte[]]$Salt = $null,
        [int]$Iterations = 1
    )

    try {
        switch ($Algorithm.ToUpper()) {
            "SHA256" {
                $sha256 = [System.Security.Cryptography.SHA256]::Create()
                $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($InputString))
                $sha256.Dispose()
            }
            "SHA512" {
                $sha512 = [System.Security.Cryptography.SHA512]::Create()
                $hashBytes = $sha512.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($InputString))
                $sha512.Dispose()
            }
            "PBKDF2" {
                if (-not $Salt) {
                    $Salt = [byte[]]::new($global:Config.SaltSize)
                    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
                    $rng.GetBytes($Salt)
                    $rng.Dispose()
                }
                $pbkdf2 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
                    $InputString,
                    $Salt,
                    $Iterations,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA512
                )
                $hashBytes = $pbkdf2.GetBytes([math]::Min($Length, 64))
                $pbkdf2.Dispose()
            }
            "ARGON2" {
                if (-not (Get-Module -Name Argon2 -ListAvailable)) {
                    Install-Module -Name Argon2 -Force -Scope CurrentUser -Confirm:$false
                }
                Import-Module Argon2
                $hashBytes = [Argon2]::Hash($InputString, $Salt, $Iterations)
            }
            default {
                throw "Algoritmo não suportado: $Algorithm"
            }
        }

        # Ajusta o tamanho do hash se necessário
        if ($hashBytes.Length -gt $Length) {
            $hashBytes = $hashBytes[0..($Length-1)]
        }
        elseif ($hashBytes.Length -lt $Length) {
            $extraBytes = [byte[]]::new($Length - $hashBytes.Length)
            $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            $rng.GetBytes($extraBytes)
            $rng.Dispose()
            $hashBytes += $extraBytes
        }

        # Formata a saída
        switch ($global:Config.OutputFormat) {
            "Hexadecimal" {
                $hashOutput = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
            }
            "Base64" {
                $hashOutput = [Convert]::ToBase64String($hashBytes)
            }
            "Base64URL" {
                $hashOutput = [Convert]::ToBase64String($hashBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
            }
        }

        # Retorna o resultado
        [PSCustomObject]@{
            Algorithm = $Algorithm
            Length = $Length
            Salt = if ($Salt) { [Convert]::ToBase64String($Salt) } else { $null }
            Iterations = if ($Iterations -gt 1) { $Iterations } else { $null }
            Hash = $hashOutput
            Bytes = $hashBytes
        }
    }
    catch {
        Write-Host "Erro ao gerar hash: $_" -ForegroundColor Red
        return $null
    }
}

function Show-HashResult {
    param (
        [PSCustomObject]$HashResult
    )

    Clear-Host
    Write-Host "========== RESULTADO DA GERAÇÃO ==========" -ForegroundColor Green
    
    if ($global:Config.ShowDetails) {
        Write-Host "Algoritmo: $($HashResult.Algorithm)" -ForegroundColor Cyan
        if ($HashResult.Iterations) {
            Write-Host "Iterações: $($HashResult.Iterations)" -ForegroundColor Yellow
        }
        if ($HashResult.Salt) {
            Write-Host "Salt: $($HashResult.Salt)" -ForegroundColor Magenta
        }
        Write-Host "Tamanho: $($HashResult.Length) bytes ($($HashResult.Length * 8) bits)" -ForegroundColor Yellow
        Write-Host "Formato: $($global:Config.OutputFormat)" -ForegroundColor Cyan
    }
    
    Write-Host "`nHASH GERADO:" -ForegroundColor Green
    Write-Host $HashResult.Hash -ForegroundColor White -BackgroundColor DarkGray
    
    if ($global:Config.AutoCopyToClipboard) {
        $HashResult.Hash | Set-Clipboard
        Write-Host "`nHash copiado para a área de transferência!" -ForegroundColor Green
    }
    
    Write-Host "`nPressione qualquer tecla para continuar..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main
$host.UI.RawUI.WindowTitle = "Sistema Anoitecer - Gerador PRO"
$host.PrivateData.ProgressBackgroundColor = "Black"
$host.PrivateData.ProgressForegroundColor = "Cyan"

do {
    Show-MainMenu
    $selection = Read-Host "`nOpção"

    switch ($selection) {
        '1' {
            $inputString = Read-Host "Digite o texto para gerar hash"
            $hashResult = Get-Hash -InputString $inputString -Algorithm $global:Config.HashAlgorithm -Length $global:Config.HashSize
            if ($hashResult) { Show-HashResult $hashResult }
        }
        '2' {
            $inputString = Read-Host "Digite o texto para gerar hash com salt"
            $hashResult = Get-Hash -InputString $inputString -Algorithm "SHA512" -Length $global:Config.HashSize -Salt ([byte[]]::new($global:Config.SaltSize))
            if ($hashResult) { Show-HashResult $hashResult }
        }
        '3' {
            $inputString = Read-Host "Digite o texto para gerar hash PBKDF2"
            $hashResult = Get-Hash -InputString $inputString -Algorithm "PBKDF2" -Length $global:Config.HashSize -Iterations $global:Config.PBKDF2Iterations
            if ($hashResult) { Show-HashResult $hashResult }
        }
        '4' {
            $inputString = Read-Host "Digite o texto para gerar hash Argon2"
            $hashResult = Get-Hash -InputString $inputString -Algorithm "ARGON2" -Length $global:Config.HashSize -Iterations $global:Config.PBKDF2Iterations
            if ($hashResult) { Show-HashResult $hashResult }
        }
        '5' {
            do {
                Show-ConfigMenu
                $configSelection = Read-Host "`nOpção de configuração"
                
                switch ($configSelection) {
                    '1' {
                        $algorithms = @("SHA256", "SHA512", "PBKDF2", "Argon2")
                        $newAlg = $algorithms | Out-GridView -Title "Selecione o algoritmo principal" -OutputMode Single
                        if ($newAlg) { $global:Config.HashAlgorithm = $newAlg }
                    }
                    '2' {
                        $newSize = Read-Host "Digite o tamanho do salt (16-64 bytes)"
                        if ($newSize -match '^\d+$' -and [int]$newSize -ge 16 -and [int]$newSize -le 64) {
                            $global:Config.SaltSize = [int]$newSize
                        } else {
                            Write-Host "Tamanho inválido! Use valores entre 16 e 64." -ForegroundColor Red
                            Start-Sleep -Seconds 2
                        }
                    }
                    '3' {
                        $newSize = Read-Host "Digite o tamanho do hash ($($global:Config.MinHashSize)-$($global:Config.MaxHashSize) bytes)"
                        if ($newSize -match '^\d+$' -and [int]$newSize -ge $global:Config.MinHashSize -and [int]$newSize -le $global:Config.MaxHashSize) {
                            $global:Config.HashSize = [int]$newSize
                        } else {
                            Write-Host "Tamanho inválido! Use valores entre $($global:Config.MinHashSize) e $($global:Config.MaxHashSize)." -ForegroundColor Red
                            Start-Sleep -Seconds 2
                        }
                    }
                    '4' {
                        $newIter = Read-Host "Digite o número de iterações ($($global:Config.MinIterations)-$($global:Config.MaxIterations))"
                        if ($newIter -match '^\d+$' -and [int]$newIter -ge $global:Config.MinIterations -and [int]$newIter -le $global:Config.MaxIterations) {
                            $global:Config.PBKDF2Iterations = [int]$newIter
                        } else {
                            Write-Host "Valor inválido! Use valores entre $($global:Config.MinIterations) e $($global:Config.MaxIterations)." -ForegroundColor Red
                            Start-Sleep -Seconds 2
                        }
                    }
                    '5' {
                        $global:Config.Argon2MemoryCost = Read-Host "Custo de memória (KB) [Atual: $($global:Config.Argon2MemoryCost)]"
                        $global:Config.Argon2Parallelism = Read-Host "Grau de paralelismo [Atual: $($global:Config.Argon2Parallelism)]"
                    }
                    '6' {
                        $formats = @("Hexadecimal", "Base64", "Base64URL")
                        $newFormat = $formats | Out-GridView -Title "Selecione o formato de saída" -OutputMode Single
                        if ($newFormat) { $global:Config.OutputFormat = $newFormat }
                    }
                    '7' {
                        $global:Config.AutoCopyToClipboard = -not $global:Config.AutoCopyToClipboard
                        Write-Host "Copiar automaticamente: $($global:Config.AutoCopyToClipboard)" -ForegroundColor Green
                        Start-Sleep -Seconds 1
                    }
                    '8' {
                        $global:Config.ShowDetails = -not $global:Config.ShowDetails
                        Write-Host "Mostrar detalhes: $($global:Config.ShowDetails)" -ForegroundColor Green
                        Start-Sleep -Seconds 1
                    }
                    '9' {
                        $global:Config = @{
                            HashAlgorithm = "SHA256"
                            SaltSize = 32
                            HashSize = 32
                            MinHashSize = 16
                            MaxHashSize = 128
                            PBKDF2Iterations = 100000
                            MinIterations = 10000
                            MaxIterations = 1000000
                            Argon2MemoryCost = 65536
                            Argon2Parallelism = 4
                            OutputFormat = "Hexadecimal"
                            AutoCopyToClipboard = $true
                            ShowDetails = $true
                        }
                        Write-Host "Configurações restauradas para os valores padrão" -ForegroundColor Green
                        Start-Sleep -Seconds 2
                    }
                }
            } while ($configSelection -notin 'R','Q')
        }
        '6' {
            Clear-Host
            Write-Host "========== SOBRE O SISTEMA ==========" -ForegroundColor Cyan
            Write-Host "Sistema de Geração de Hashes Anoitecer PRO"
            Write-Host "Versão: 3.0"
            Write-Host "Recursos:"
            Write-Host "- 4 algoritmos de hashing"
            Write-Host "- Controle total do tamanho do hash"
            Write-Host "- Configuração avançada de parâmetros"
            Write-Host "- Múltiplos formatos de saída"
            Write-Host "`nPressione qualquer tecla para continuar..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
} while ($selection -ne 'Q')

Write-Host "Encerrando o sistema..." -ForegroundColor Yellow
Start-Sleep -Seconds 2