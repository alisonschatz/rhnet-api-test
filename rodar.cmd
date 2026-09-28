@echo off
setlocal
REM ------------------------------------------------------------
REM  Roda os testes, gera o relatorio Allure e o abre.
REM
REM    .\rodar              -> tudo em hml (no PowerShell, use sempre .\rodar)
REM    .\rodar prd          -> tudo em prd
REM    .\rodar hml smoke    -> so os testes @smoke em hml
REM
REM  O terminal mostra apenas o resumo. A saida completa do Maven
REM  fica em target\execucao.log.
REM ------------------------------------------------------------
cd /d "%~dp0"
chcp 65001 >nul

set AMBIENTE=%~1
if "%AMBIENTE%"=="" set AMBIENTE=hml

if /I not "%AMBIENTE%"=="hml" if /I not "%AMBIENTE%"=="prd" (
  echo Ambiente inválido: %AMBIENTE%. Use hml ou prd.
  exit /b 1
)

if not exist ".env.%AMBIENTE%" (
  echo Arquivo .env.%AMBIENTE% não encontrado.
  echo Copie o .env.example para .env.%AMBIENTE% e preencha as credenciais.
  exit /b 1
)

set TAGS=%~2
if "%TAGS%"=="" goto tags_ok
if not "%TAGS:~0,1%"=="@" set TAGS=@%TAGS%
:tags_ok

set AMB=HML
if /I "%AMBIENTE%"=="prd" set AMB=PRD
set TITULO=Testes em %AMB%
if not "%TAGS%"=="" set TITULO=Testes em %AMB% - %TAGS%

if not exist target mkdir target
del /q target\resumo-execucao.json target\resumo-console.txt 2>nul

echo.
echo %TITULO%
echo Executando... a primeira execução pode levar alguns minutos.

set ARGS=-B --no-transfer-progress test -Dkarate.env=%AMBIENTE% -Drodar=true -Dmaven.test.failure.ignore=true
if not "%TAGS%"=="" set ARGS=%ARGS% -Dtags=%TAGS%
call mvnw.cmd %ARGS% > target\execucao.log 2>&1

if exist "target\resumo-console.txt" goto testes_ok
echo.
echo === A EXECUÇÃO FALHOU ANTES DOS TESTES ===
echo Últimas linhas do log - completo em target\execucao.log:
echo.
powershell -NoProfile -Command "Get-Content -Encoding UTF8 target\execucao.log -Tail 40"
exit /b 1

:testes_ok
echo.
type target\resumo-console.txt
set FALHARAM=1
for /f %%i in ('powershell -NoProfile -Command "(Get-Content -Raw -Encoding UTF8 target\resumo-execucao.json | ConvertFrom-Json).falharam"') do set FALHARAM=%%i

echo.
echo Gerando relatório Allure...
set ALLURE_AMBIENTE=%AMBIENTE%
call mvnw.cmd -B --no-transfer-progress allure:report > target\allure.log 2>&1
java scripts\NomeRelatorioAllure.java target\allure-report\index.html %AMBIENTE% >> target\allure.log 2>&1

set ALLURE=target\allure-report\index.html
set DETALHE=target\karate-reports\karate-summary.html
echo.
if exist "%ALLURE%" (echo Relatório Allure:  %ALLURE%) else (echo Relatório Allure não gerado - veja target\allure.log)
echo Detalhe técnico:   %DETALHE%
echo Log completo:      target\execucao.log
if exist "%ALLURE%" (start "" "%ALLURE%") else (start "" "%DETALHE%")

if "%FALHARAM%"=="0" exit /b 0
exit /b 1
