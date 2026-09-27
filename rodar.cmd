@echo off
setlocal
REM ------------------------------------------------------------
REM  Roda os testes e abre o relatorio.
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

set PAINEL=target\cucumber-html-reports\overview-features.html
set DETALHE=target\karate-reports\karate-summary.html
echo.
if not exist "%DETALHE%" (
  echo === A EXECUCAO FALHOU ANTES DOS TESTES - veja as mensagens acima ===
  exit /b %RESULTADO%
)
if %RESULTADO%==0 (echo === TODOS OS TESTES PASSARAM ===) else (echo === HA TESTES FALHANDO ===)
echo.
echo Painel de resultados:  %PAINEL%
echo Detalhe tecnico:       %DETALHE%
if exist "%PAINEL%" (start "" "%PAINEL%") else (start "" "%DETALHE%")
exit /b %RESULTADO%
