@echo off
:: Sistema de Geração de Hashes Anoitecer
title Sistema Anoitecer - Hash Generator
color 0B
cls

echo ===========================================
echo      SISTEMA ANOITECER - HASH GENERATOR
echo ===========================================
echo.

set /p usuario="Digite o usuario: "
set /p senha="Digite a senha: "

if "%usuario%"=="anoitecer" (
    if "%senha%"=="anoitecer" (
        cls
        echo Autenticacao bem-sucedida!
        echo Iniciando Sistema de Hashes...
        timeout /t 2 /nobreak >nul
        powershell -ExecutionPolicy Bypass -File "Gerador_Hashes.ps1"
    ) else (
        echo Senha incorreta!
        timeout /t 2 /nobreak >nul
        exit
    )
) else (
    echo Usuario incorreto!
    timeout /t 2 /nobreak >nul
    exit
)