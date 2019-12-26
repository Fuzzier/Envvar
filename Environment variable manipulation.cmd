:: {{{ Environment variable manipulation. 20160317
:: =============================================================================
:: Environment variable manipulation.
:: To prevent using DELAYEDEXPANSION, the manipulation of
:: the environment variable is encapsulated in functions.
:: To extract the value of an environment variable, AFAIK,
:: there're two methods.
:: Before I go into the details, let's observe the basic fact that
:: "macro substitution happens only once, then the code is evaluated".
:: For example:
::   A subroutine ':Assign' is required, which assigns the second argument
::   (a string) to the first argument (the name of an environment variable).
::   <code>
::     :Assign1
::       SET "%~1=%~2"
::       EXIT /B
::   </code>
::   Let's invoke the subroutine like this
::   <code>
::     CALL :Assign1 "DST_VAR" "abc"
::   </code>
::   Then in the subroutine, "%1" is "DST_VAR" and "%2" is "abc", and
::   <code>
::     SET "%~1=%~2"
::   </code>
::   is substituted as
::   <code>
::     SET "DST_VAR=abc"
::   </code>
::   and the value of the environment variable 'DST_VAR' becomes 'abc'.
::
::   However, let's look at another example.
::   A subroutine ':Assign2' is required, which assigns the value of
::   the first argument (the name of the source environment variable) to
::   the second argument (the name of the destination environment variable).
::   <code>
::     :Assign2
::       SET "%~2=%%%~1%%"
::       EXIT /B
::   </code>
::   Let's invoke the subroutine like this
::   <code>
::     SET SRC_VAR=abc
::     CALL :Assign2 "SRC_VAR" "DST_VAR"
::   </code>
::   Then in the subroutine, "%1" is "SRC_VAR", and "%2" is "DST_VAR", and
::   <code>
::     SET "%~2=%%%~1%%"
::   </code>
::   is substituted as
::   <code>
::     SET "DST_VAR=%SRC_VAR%"
::   </code>
::   Unfortunately, '%SRC_VAR%' will not receive a second substitution,
::   and the value of 'DST_VAR' becomes '%SRC_VAR%',
::   not 'abc' (the value of 'SRC_VAR').
::
:: In order to assign the value of 'SRC_VAR' to 'DST_VAR',
:: there's must be a second macro substitution.
:: The first time, '%%%~2%%' is substituted into '%SRC_VAR%'.
:: The second time, '%SRC_VAR%' substituted into the value of 'SRC_VAR'.
:: There're two commands, IFAIK, that does the job.
:: 1. FOR.
::   The usable form is
::   <code>
::     FOR /F %%s IN ('command') DO (command)
::   </code>
::   When the first command block within the single quotes is evaluated,
::   macro substitution happens again.
::   For example:
::   <code>
::     :Assign3
::       FOR /F "delims=" %%s IN ('ECHO "%%%~1%%"') DO (
::         SET "%~2=%%~s"
::       )
::       EXIT /B
::   </code>
::   And let's invoke the subroutine like this
::   <code>
::     SET SRC_VAR=abc
::     CALL :Assign3 "SRC_VAR" "DST_VAR"
::   </code>
::   In the subroutine, "%1" is "SRC_VAR", and "%2" is "DST_VAR".
::   The first macro substitution changes the code into
::   <code>
::     FOR /F "delims=" %s IN ('ECHO "%SRC_VAR%"') DO (
::       SET "DST_VAR=%~s"
::     )
::   </code>
::   The second macro substitution happens when the first command block
::   <code>
::     ECHO "%SRC_VAR%"
::   </code>
::   is evaluated, which prints the value of 'SRC_VAR' like this
::   <code>
::     "abc"
::   </code>
::   This printed list is captured by the 'FOR' command, and further
::   captured by the variable '%s' in the second command block.
::   In the second command block, the variable '%s' gets substituted,
::   and the value of the variable '%s' is assigned to 'DST_VAR'.
::   <code>
::     SET "DST_VAR=abc"
::   </code>
::   And this completes the assignment.
::
::   Please note that in the second command block, only the variables
::   get substituted. The following subroutine will not work.
::   <code>
::     :Assign4
::       FOR /F "delims=" %%s IN ("0") DO (
::         ECHO %%~s > NUL
::         SET "%~2=%%%~1%%"
::       )
::       EXIT /B
::   </code>
::   If it's invoked like this
::   <code>
::     SET SRC_VAR=abc
::     CALL :Assign3 "SRC_VAR" "DST_VAR"
::   </code>
::   The second command block is substituted into
::   <code>
::     ECHO %~s > NUL
::     SET "DST_VAR=%SRC_VAR%"
::   </code>
::   When the second command block is evaluated, only '%s' get substituted.
::   '%SRC_VAR%' is never substituted again, and is assigned to 'DST_VAR'
::   directly.
::
::   However, there's one drawback of this method.
::   If 'SRC_VAR' is empty (not defined), then '%SRC_VAR%' will
::   not be substituted into an empty string. Thus, 'ECHO "%SRC_VAR%"'
::   displays "%SRC_VAR%", instead of an empty line.
::   That is, if ':Assign3' is invoked like this
::   <code>
::     SET SRC_VAR=
::     CALL :Assign3 "SRC_VAR" "DST_VAR"
::   </code>
::   In the subroutine, the first macro substitution changes the code into
::   <code>
::     FOR /F "delims=" %s IN ('ECHO "%SRC_VAR%"') DO (
::       SET "DST_VAR=%~s"
::     )
::   </code>
::   When the first command block
::   <code>
::     ECHO "%SRC_VAR%"
::   </code>
::   is evaluated, it prints
::   <code>
::     "%SRC_VAR%"
::   </code>
::   instead of substituting '%SRC_VAR%' into nothing.
::   This renders additional burden to check the value of '%~s'.
::   If "%~s" equals to "%SRC_VAR%", then the 'SRC_VAR' is empty;
::   otherwise, use the value of '%~s'.
::   <code>
::     :Assign5
::       FOR /F "delims=" %%s IN ('ECHO "%%%~1%%"') DO (
::         IF "%%~s"=="%%%~1%%" (
::           SET "%~2="
::         ) ELSE (
::           SEt "%~2=%%~s"
::         )
::       )
::       EXIT /B
::   </code>
::   But it the value of 'SRC_VAR' is indeed "%SRC_VAR%", this method fails.
::   For example:
::   <code>
::     SET SRC_VAR=
::     SET SRC_VAR=%SRC_VAR%
::     CALL :Assign5 "SRC_VAR" "DST_VAR"
::   </code>
::   The value of 'DST_VAR' should be assigned to '%SRC_VAR%',
::   but the value of 'DST_VAR' will not be touched.
::
:: 2. CALL.
::   The 'CALL' command provides another and better solution.
::     CALL :Subroutine arguments
::   When CALL command is evaluated, the arguments get another round of
::   macro substitution.
::   For example:
::   <code>
::     :Assign6
::       CALL :Assign1 "%~2" "%%%~1%%"
::       EXIT /B
::   </code>
::   Let's invoke the subroutine like this
::   <code>
::     SET SRC_VAR=abc
::     CALL :Assign6 "SRC_VAR" "DST_VAR"
::   </code>
::   In the subroutine, the code is substituted as
::   <code>
::     CALL :Assign1 "DST_VAR" "%SRC_VAR%"
::   </code>
::   When the 'CALL' command is evaluated, an other round of macro substitution
::   takes place, which changeds the code like this
::   <code>
::     CALL :Assign1 "DST_VAR" "abc"
::   </code>
::   This completes the assignment.
::
::   Even if 'SRC_VAR' is empty (not defined), this method works as is.
::   For example, let's invoke the subroutine like this
::   <code>
::     SET SRC_VAR=
::     CALL :Assign6 "SRC_VAR" "DST_VAR"
::   </code>
::   In the subroutine, the code is substituted as
::   <code>
::     CALL :Assign1 "DST_VAR" "%SRC_VAR%"
::   </code>
::   When the 'CALL' command is evaluated, an other round of macro substitution
::   takes place, which changeds the code like this
::   <code>
::     CALL :Assign1 "DST_VAR" ""
::   </code>
::   This completes the assignment.
::
::   Let's take a deeper look at the 'CALL' command, and it's just amazing.
::   First, the second macro substitution works upon the name of the subroutine.
::   Second, empty environment variables are substituted into nothing.
::   <code>
::     :Assign7
::       CALL :Assign%%%~1%% "%%%~2%%" "%%%~3%%" "%%%~4%%"
::       EXIT /B
::   </code>
::   Let's invoke the subroutine like this
::   <code>
::     SET INDEX=6
::     SET ARG1=SRC_VAR
::     SET ARG2=
::     SET ARG3=abc
::     CALL :Assign7 "INDEX" "ARG1" "ARG2" "ARG3"
::   </code>
::   In the subroutine, the code is substituted into
::   <code>
::     CALL :Assign%INDEX% "%ARG1%" "%ARG2%" "%ARG3%"
::   </code>
::   When 'CALL' command is evaluated, a second substitution changes the code
::   into
::   <code>
::     CALL :Assign6 "SRC_VAR" "" "abc"
::   </code>
::
::   The second substitution of the 'CALL' command is able to dereference
::   an environment variable for only one level.
::   The following code will not work
::   <code>
::     :Assign8
::       CALL :Assign%%%%%%%~1%%%%%% "%%%%%%%~2%%%%%%"
::       EXIT /B
::   </code>
::   For example, let's invoke the subroutine like this
::   <code>
::     SET INDEX=6
::     SET PINDEX=INDEX
::     SET ARG="DST_VAR"
::     SET PARG=ARG
::     CALL :Assign8 "PINDEX" "PARG"
::   </code>
::   In the subroutine, the code is substituted into
::   <code>
::     CALL :Assign%%%PINDEX%%% "%%%PARG%%%"
::   </code>
::   When 'CALL' command is evaluated, a second substitution substitute
::   '%PINDEX%' into 'INDEX', and '%%' into '%'. The code becomes
::   <code>
::     CALL :Assign%INDEX% "%ARG%"
::   </code>
::   However, the substitution process stops here, and an error will be
::   generated that states
::   "The system cannot find the batch label specified - Assign%INDEX%".
::
::   A good usage of 'CALL' command is to use the second substitution to
::   mimic the behavior of delayed expansion.
::   <code>
::     @param %1 The name of the environment variable.
::     :ValueEcho
::       ECHO %~1
::       EXIT /B
::
::     :DelayedEcho
::       SET ARG=1
::       CALL :ValueEcho "%%ARG%%"
::       SET ARG=2
::       CALL :ValueEcho "%%ARG%%"
::       EXIT /B
::   </code>
::
::   A powerful usage of 'CALL' command is to enable callbacks.
::   <code>
::     @param %1 The value combined with tokens separated by ';'.
::     @param %2 The environment variable holding the name of
::               the callback subroutine.
::     :ValueTokenize
::       FOR /F "tokens=1,* delims=;" %%i IN ("%~1") DO (
::         CALL :"%%%~2%%" "%%~i"
::         IF NOT "%%~j"=="" CALL :ValueTokenize "%%~j" "%~2"
::       )
::       EXIT /B
::
::     @param %1 The value of the token.
::     :Cb1
::       EXIT /B
::
::     @param %1 The value of the token.
::     :Cb2
::       EXIT /B
::
::     :DoViaCallback
::       SET PCALLBCAK=Cb1
::       CALL :ValueTokenize "12;34;56" "PCALLBCAK"
::       SET PCALLBCAK=Cb2
::       CALL :ValueTokenize "12;34;56" "PCALLBCAK"
::       EXIT /B
::   </code>
::
::
::  Notes about using multiple '%ERRORLEVEL%'s.
::  <code>
::    :ValueEq
::      IF "%~1"=="%~2" ( EXIT /B 1 ) ELSE ( EXIT /B 0 )
::
::    :Test1
::      CALL :ValueEq "a" "b"
::      IF ERRORLEVEL 1 (
::        ECHO bad!
::      ) ELSE (
::        CALL :ValueEq "a" "a"
::        IF ERRORLEVEL 1 (
::          ECHO ok!
::        ) ELSE (
::          ECHO bad!
::        )
::      )
::      EXIT /B
::
::    :Test2b
::      CALL :ValueEq "a" "b"
::      IF %ERRORLEVEL% EQU 1 (
::        ECHO bad!
::      ) ELSE (
::        CALL :ValueEq "a" "a"
::        IF %ERRORLEVEL% EQU 1 (
::          ECHO ok!
::        ) ELSE (
::          ECHO bad!
::        )
::      )
::      EXIT /B
::
::    :Test2
::      CALL :ValueEq "a" "b"
::      IF %ERRORLEVEL% EQU 1 (
::        ECHO bad!
::        EXIT /B
::      )
::      CALL :ValueEq "a" "a"
::      IF %ERRORLEVEL% EQU 1 (
::        ECHO ok!
::      ) ELSE (
::        ECHO bad!
::      )
::      EXIT /B
::
::    :Test3b
::      CALL :ValueEq "a" "b"
::      IF "%ERRORLEVEL%"=="1" (
::        ECHO bad!
::      ) ELSE (
::        CALL :ValueEq "a" "a"
::        IF "%ERRORLEVEL%"=="1" (
::          ECHO ok!
::        ) ELSE (
::          ECHO bad!
::        )
::      )
::      EXIT /B
::
::    :Test3
::      CALL :ValueEq "a" "b"
::      IF "%ERRORLEVEL%"=="1" (
::        ECHO bad!
::        EXIT /B
::      )
::      CALL :ValueEq "a" "a"
::      IF "%ERRORLEVEL%"=="1" (
::        ECHO ok!
::      ) ELSE (
::        ECHO bad!
::      )
::      EXIT /B
::  </code>
::  The subroutines ':Test1', ':Test2' and ':Test3' are correct.
::  The subroutines ':Test2b' and ':Test3b' are incorrect.
::
::  When using '%ERRORLEVEL%' (macro form), do not put multiple '%ERRORLEVEL%'s
::  within a single command.
::  A single command performs macro substitution only once.
::  In ':Test2b' and ':Test3b', multiple '%ERRORLEVEL%'s are put within
::  a single 'IF-ELSE' command. When the 'ELSE' command block is evaluated,
::  the '%ERRORLEVEL%' is not substituted again.
::
::  ':Test1' doesn't use macro form of 'ERRORLEVEL', thus it doesn't suffer
::  from this problem.
::
::  Also note that, 'IF ERRORLEVEL n' means 'IF ERRORLEVEL >= n'.
::  Don't mistake it to be 'IF ERRORLEVEL == n'.
::
:: =============================================================================

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
:: @param %1 The subname of the evironment variable.
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

:: }}}
