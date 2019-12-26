@ECHO OFF

:: This is a script that provides subroutines for manipulating environment
:: variables.

:: @brief Invoke a subroutine in this script.
:: @param %1 The name of the subroutine in this script.
::           For example, :EnvvarAddPath
:: @param %2 The additional argument.
:: @param %3 The additional argument.
:: @param %4 The additional argument.
:: @param %5 The additional argument.
:: @param %6 The additional argument.
:: @param %7 The additional argument.
:: @param %8 The additional argument.
:: @param %9 The additional argument.
IF "%~1" NEQ "" (
  CALL %1 %2 %3 %4 %5 %6 %7 %8 %9
)
EXIT /B


:: ============ ErrorLevelTest Begin ============
:: @brief Test the ERRORLEVEL.
:: @param %1 The value to test.
:: @param %2 An optional string.
:ErrorLevelTest
IF "%ERRORLEVEL%"=="%~1" (
  ECHO test passed. %~2
) ELSE (
  ECHO * test failed. %~2
)
EXIT /B
:: ============ ErrorLevelTest End ============


:: ============ ValueEcho Begin ============
:: @brief Prints a value.
:: @param %1 The value to print.
:ValueEcho
IF NOT "%~1"=="" ECHO %~1
EXIT /B
:: ============ ValueEcho End ============


:: ============ ValueEq Begin ============
:: @brief Are two values equal?
:: @param %1 The lhs value.
:: @param %1 The rhs value.
:: @return Return 1 if they're equal.
:ValueEq
IF "%~1"=="%~2" ( EXIT /B 1 ) ELSE ( EXIT /B 0 )
:: ============ ValueEq End ============


:: ============ ValueFind Begin ============
:: @brief Find string in a value.
:: @param %1 The value.
:: @param %2 The string.
:: @param %3 The options (see help for FINDSTR).
:: @return Return 1 if found.
:ValueFind
FOR /F "delims=" %%s IN ('ECHO "%~1" ^| FINDSTR %~3 /C:"%~2"') DO (
  EXIT /B 1
)
EXIT /B 0
:: ============ ValueFind End ============


:: ============ ValueTokenize Begin ============
:: @brief Tokenize a value.
:: @param %1 The value.
:: @param %2 The delimiters.
:: @param %3 The name of callback subroutine.
:: @param %4 The additional argument passed to the callback.
:: @param %5 The additional argument passed to the callback.
:: @param %6 The additional argument passed to the callback.
:ValueTokenize
IF NOT "%~1"=="" (
  FOR /F "tokens=1,* delims=%~2" %%i IN ("%~1") DO (
    CALL :%~3 "%%~i" %4 %5 %6
    IF NOT "%%~j"=="" CALL :ValueTokenize "%%~j" %2 %3 %4 %5 %6
  )
)
EXIT /B
:: ============ ValueTokenize End ============


:: ============ EnvvarEcho Begin ============
:: @brief Prints the value of an environment variable.
:: @param %1 The name of the environment variable.
:: @remarks The behavior differs from the 'ECHO' command when the environment
::          variable is empty (not defined), as this subroutine prints nothing.
:EnvvarEcho
CALL :ValueEcho "%%%~1%%"
EXIT /B
:: ============ EnvvarEcho End ============


:: ============ EnvvarIs Begin ============
:: @brief Check the value of an environment variable.
:: @param %1 The name of the environment variable.
:: @param %2 The value.
:: @return Returns 1 if true.
:EnvvarIs
CALL :ValueEq "%%%~1%%" "%~2"
EXIT /B %ERRORLEVEL%
:: ============ EnvvarIs End ============


:: ============ EnvvarEq Begin ============
:: @brief Are the values of two environment variables equal?
:: @param %1 The name of the lhs environment variable.
:: @param %2 The name of the rhs environment variable.
:: @return Returns 1 if true.
:EnvvarEq
CALL :ValueEq "%%%~1%%" "%%%~2%%"
EXIT /B %ERRORLEVEL%
:: ============ EnvvarEq End ============


:: ============ EnvvarFind Begin ============
:: @brief Find string in the value of an environment variable.
:: @param %1 The name of the environment variable.
:: @param %2 The string.
:: @param %3 The options (see help for FINDSTR).
:: @return Returns 1 if true.
:EnvvarFind
CALL :ValueFind "%%%~1%%" %2 %3
EXIT /B %ERRORLEVEL%
:: ============ EnvvarFind End ============


:: ============ EnvvarClear Begin ============
:: @brief Undefine an environment variable.
:: @param %1 The name of the environment variable.
:EnvvarClear
SET "%~1="
EXIT /B
:: ============ EnvvarClear End ============


:: ============ EnvvarSet Begin ============
:: @brief Set the value of an environment variable.
:: @param %1 The name of the environment variable.
:: @param %2 The value.
:EnvvarSet
SET "%~1=%~2"
EXIT /B
:: ============ EnvvarSet End ============


:: ============ EnvvarCopy Begin ============
:: @brief Copy the value of one environment variable to another.
:: @param %1 The name of the source environment variable.
:: @param %2 The name of the destination environment variable.
:EnvvarCopy
CALL :EnvvarSet "%~2" "%%%~1%%"
EXIT /B
:: ============ EnvvarCopy End ============


:: ============ EnvvarAdd Begin ============
:: @brief Add a value to an environment variable.
::        The value will be appended to the end of the environment variable.
::        Values added are separated with semi-colons (;).
:: @param %1 The name of the environment variable.
:: @param %2 The value to add. If the value is empty, nothing will be done.
:EnvvarAdd
IF "%~2"=="" EXIT /B

CALL :ValueEq "%%%~1%%" ""
IF ERRORLEVEL 1 (
  CALL :EnvvarSet "%~1" "%~2"
) ELSE (
  CALL :ValueEq "%%%~1:~-1%%" ";"
  IF ERRORLEVEL 1 (
    CALL :EnvvarSet "%~1" "%%%~1%%%~2"
  ) ELSE (
    CALL :EnvvarSet "%~1" "%%%~1%%;%~2"
  )
)
EXIT /B
:: ============ EnvvarAdd End ============


:: ============ EnvvarAddPath Begin ============
:: @brief Add a path to the environment variable.
:: @param %1 The name of the evironment variable.
:: @param %2 The path to add. If the path doesn't exists, nothing will be done.
:EnvvarAddPath
IF EXIST "%~2" (
  CALL :EnvvarAdd %*
  EXIT /B 1
)
EXIT /B 0
:: ============ EnvvarAddPath End ============


:: ============ EnvvarTokenize Begin ============
:: @brief Tokenize an environment variable.
:: @detail Each token in the environment variable is extracted.
::         For each token, the user-defined callback is invoked.
::         The extracted token is passed as the first argument,
::         three additional arguments are passed as well.
:: @param %1 The name of the environment variable.
:: @param %2 The delimiters.
:: @param %3 The name of callback subroutine.
:: @param %4 The additional argument passed to the callback.
:: @param %5 The additional argument passed to the callback.
:: @param %6 The additional argument passed to the callback.
:EnvvarTokenize
CALL :ValueTokenize "%%%~1%%" %2 %3 %4 %5 %6
EXIT /B
:: ============ EnvvarTokenize End ============


:: ============ EnvvarRemove Begin ============
:: @brief Remove a string to an environment variable.
:: @param %1 The name of environment variable.
:: @param %2 The delimiters.
:: @param %3 The string to find in token.
::           If the token matches the string, the token is removed from
::           the environment variable.
::           If the string is empty, nothing will be done.
:: @param %4 Search options (see help for FINDSTR).
:EnvvarRemove
IF NOT "%~3"=="" (
  SET TEMP_VAR=
  CALL :ValueTokenize "%%%~1%%" %2 "EnvvarRemoveCallback" "TEMP_VAR" %3 %4
  CALL :EnvvarSet "%~1" "%%TEMP_VAR%%"
)
EXIT /B
:: ============ EnvvarRemove End ============


:: ============ EnvvarRemoveCallback Begin ============
:: @brief Remove a string to an environment variable.
:: @param %1 The value of the token.
:: @param %2 The name of the environment variable.
:: @param %3 The string to find in token.
::           If the token matches the string, the token is removed from
::           the environment variable.
::           If the string is empty, nothing will be done.
:: @param %4 Search options (see help for FINDSTR).
:EnvvarRemoveCallback
CALL :ValueFind %1 %3 %4
IF %ERRORLEVEL% EQU 0 (
  CALL :EnvvarAdd %2 %1
)
EXIT /B
:: ============ EnvvarRemoveCallback End ============

