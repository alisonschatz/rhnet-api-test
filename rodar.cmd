@echo off
setlocal
REM ------------------------------------------------------------
REM  Roda os testes, gera o relatorio Allure e o abre.
REM
REM    .\rodar              -> tudo em hml (no PowerShell, use sempre .\rodar)
REM    .\rodar prd          -> tudo em prd
REM    .\rodar hml smoke    -> so os testes @smoke em hml
REM ------------------------------------------------------------
cd /d "%~dp0"

set AMBIENTE=%~1
if "%AMBIENTE%"=="" set AMBIENTE=hml

if /I not "%AMBIENTE%"=="hml" if /I not "%AMBIENTE%"=="prd" (
  echo Ambiente invalido: %AMBIENTE%. Use hml ou prd.
  exit /b 1
)

if not exist ".env.%AMBIENTE%" (
  echo Arquivo .env.%AMBIENTE% nao encontrado.
  echo Copie o .env.example para .env.%AMBIENTE% e preencha as credenciais.
  exit /b 1
)

set TAGS=%~2
if "%TAGS%"=="" goto tags_ok
if not "%TAGS:~0,1%"=="@" set TAGS=@%TAGS%
:tags_ok

echo.
echo === Rodando testes em %AMBIENTE% %TAGS% ===
echo.

if "%TAGS%"=="" (
  call mvnw.cmd -B --no-transfer-progress test -Dkarate.env=%AMBIENTE%
) else (
  call mvnw.cmd -B --no-transfer-progress test -Dkarate.env=%AMBIENTE% -Dtags=%TAGS%
)
set RESULTADO=%ERRORLEVEL%

if not exist "target\allure-results" (
  echo.
  echo === A EXECUCAO FALHOU ANTES DOS TESTES - veja as mensagens acima ===
  exit /b %RESULTADO%
)

echo.
echo === Gerando relatorio Allure ===
set ALLURE_AMBIENTE=%AMBIENTE%
call mvnw.cmd -B --no-transfer-progress -q allure:report

set ALLURE=target\allure-report\index.html
set DETALHE=target\karate-reports\karate-summary.html
echo.
if %RESULTADO%==0 (echo === TODOS OS TESTES PASSARAM ===) else (echo === HA TESTES FALHANDO ===)
echo.
echo Relatorio Allure:   %ALLURE%
echo Detalhe tecnico:    %DETALHE%
if exist "%ALLURE%" (start "" "%ALLURE%") else (start "" "%DETALHE%")
exit /b %RESULTADO%
