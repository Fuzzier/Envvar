<h1>Higher-level function invocation in Windows batch scripts</h1>

Updated at 20160317.

<h2>Preface</h2>

To prevent using DELAYEDEXPANSION, the manipulation of
the environment variable is encapsulated in functions.
To extract the value of an environment variable, AFAIK,
there're two methods.

Before I go into the details, let's observe the basic fact that

> macro substitution happens only once, then the code is evaluated.

For example:

A subroutine `:Assign` is required, which assigns the second argument
(a string) to the first argument (the name of an environment variable).
~~~
:Assign1
  SET "%~1=%~2"
  EXIT /B
~~~

Let's invoke the subroutine like this
~~~
CALL :Assign1 "DST_VAR" "abc"
~~~

Then in the subroutine, `%1` is `DST_VAR` and `%2` is `abc`, and
~~~
SET "%~1=%~2"
~~~

is substituted as
~~~
SET "DST_VAR=abc"
~~~

and the value of the environment variable `DST_VAR` becomes `abc`.

However, let's look at another example.
A subroutine `:Assign2` is required, which assigns the value of
the first argument (the name of the source environment variable) to
the second argument (the name of the destination environment variable).
~~~
:Assign2
  SET "%~2=%%%~1%%"
  EXIT /B
~~~

Let's invoke the subroutine like this
~~~
SET SRC_VAR=abc
CALL :Assign2 "SRC_VAR" "DST_VAR"
~~~

Then in the subroutine, `%1` is `SRC_VAR`, and `%2` is `DST_VAR`, and
~~~
SET "%~2=%%%~1%%"
~~~

is substituted as
~~~
SET "DST_VAR=%SRC_VAR%"
~~~

Unfortunately, `%SRC_VAR%` will not receive a second substitution,
and the value of `DST_VAR` becomes `%SRC_VAR%`,
not `abc` (the value of `SRC_VAR`).

<h2>Recursive macro substitution</h2>

In order to assign the value of `SRC_VAR` to `DST_VAR`,
There's must be a second macro substitution.
* Thee first time, `%%%~2%%` is substituted into `%SRC_VAR%`.
* Thee second time, `%SRC_VAR%` substituted into the value of `SRC_VAR`.

There're two commands, IFAIK, that does the job.

<h3>1. The 'FOR` command</h3>

The usable form is
~~~
FOR /F %%s IN ('command') DO (command)
~~~

When the first command block within the single quotes is evaluated,
macro substitution happens again.

For example:
~~~
:Assign3
  FOR /F "delims=" %%s IN ('ECHO "%%%~1%%"') DO (
    SET "%~2=%%~s"
  )
  EXIT /B
~~~

And let's invoke the subroutine like this
~~~
SET SRC_VAR=abc
CALL :Assign3 "SRC_VAR" "DST_VAR"
~~~

In the subroutine, `%1` is `SRC_VAR`, and `%2` is `DST_VAR`.
The first macro substitution changes the code into
~~~
FOR /F "delims=" %s IN ('ECHO "%SRC_VAR%"') DO (
  SET "DST_VAR=%~s"
)
~~~

The second macro substitution happens when the first command block
~~~
ECHO "%SRC_VAR%"
~~~

is evaluated, which prints the value of `SRC_VAR` like this
~~~
"abc"
~~~

This printed list is captured by the `FOR` command, and further
captured by the variable `%s` in the second command block.
In the second command block, the variable `%s` gets substituted,
and the value of the variable `%s` is assigned to `DST_VAR`.
~~~
SET "DST_VAR=abc"
~~~

And this completes the assignment.

Please note that in the second command block, only the variables
get substituted. The following subroutine will not work.
~~~
:Assign4
  FOR /F "delims=" %%s IN ("0") DO (
    ECHO %%~s > NUL
    SET "%~2=%%%~1%%"
  )
  EXIT /B
~~~

If it's invoked like this
~~~
SET SRC_VAR=abc
CALL :Assign3 "SRC_VAR" "DST_VAR"
~~~

The second command block is substituted into
~~~
ECHO %~s > NUL
SET "DST_VAR=%SRC_VAR%"
~~~

When the second command block is evaluated, only `%s` get substituted.
`%SRC_VAR%` is never substituted again, and is assigned to `DST_VAR`
directly.

However, there's one drawback of this method.
If `SRC_VAR` is empty (not defined), then `%SRC_VAR%` will
not be substituted into an empty string. Thus, `ECHO "%SRC_VAR%"`
displays `%SRC_VAR%`, instead of an empty line.

That is, if `:Assign3` is invoked like this
~~~
SET SRC_VAR=
CALL :Assign3 "SRC_VAR" "DST_VAR"
~~~

In the subroutine, the first macro substitution changes the code into
~~~
FOR /F "delims=" %s IN ('ECHO "%SRC_VAR%"') DO (
  SET "DST_VAR=%~s"
)
~~~

When the first command block
~~~
ECHO "%SRC_VAR%"
~~~

is evaluated, it prints
~~~
"%SRC_VAR%"
~~~

instead of substituting `%SRC_VAR%` into nothing.
This renders additional burden to check the value of `%~s`.
If `%~s` equals to `%SRC_VAR%`, then the `SRC_VAR` is empty;
otherwise, use the value of `%~s`.
~~~
:Assign5
  FOR /F "delims=" %%s IN ('ECHO "%%%~1%%"') DO (
    IF "%%~s"=="%%%~1%%" (
      SET "%~2="
    ) ELSE (
      SEt "%~2=%%~s"
    )
  )
  EXIT /B
~~~

But if the value of `SRC_VAR` is indeed `%SRC_VAR%`, this method fails.
For example:
~~~
SET SRC_VAR=
SET SRC_VAR=%SRC_VAR%
CALL :Assign5 "SRC_VAR" "DST_VAR"
~~~

The value of `DST_VAR` should be assigned to `%SRC_VAR%`,
but the value of `DST_VAR` will not be touched.

<h3>2. The 'CALL' command</h3>

The `CALL` command provides another and better solution.
~~~
CALL :Subroutine arguments
~~~

When `CALL` command is evaluated, the arguments get another round of
macro substitution.

For example:
~~~
:Assign6
  CALL :Assign1 "%~2" "%%%~1%%"
  EXIT /B
~~~

Let's invoke the subroutine like this
~~~
SET SRC_VAR=abc
CALL :Assign6 "SRC_VAR" "DST_VAR"
~~~

In the subroutine, the code is substituted as
~~~
CALL :Assign1 "DST_VAR" "%SRC_VAR%"
~~~

When the `CALL` command is evaluated, an other round of macro substitution
takes place, which changeds the code like this
~~~
CALL :Assign1 "DST_VAR" "abc"
~~~
This completes the assignment.

Even if `SRC_VAR` is empty (not defined), this method works as is.
For example, let's invoke the subroutine like this
~~~
SET SRC_VAR=
CALL :Assign6 "SRC_VAR" "DST_VAR"
~~~

In the subroutine, the code is substituted as
~~~
CALL :Assign1 "DST_VAR" "%SRC_VAR%"
~~~

When the `CALL` command is evaluated, an other round of macro substitution
takes place, which changes the code like this
~~~
CALL :Assign1 "DST_VAR" ""
~~~

This completes the assignment.

Let's take a deeper look at the `CALL` command, and it's just amazing.
* First, the second macro substitution works upon the name of the subroutine.
* Second, empty environment variables are substituted into nothing.

~~~
:Assign7
  CALL :Assign%%%~1%% "%%%~2%%" "%%%~3%%" "%%%~4%%"
  EXIT /B
~~~

Let's invoke the subroutine like this
~~~
SET INDEX=6
SET ARG1=SRC_VAR
SET ARG2=
SET ARG3=abc
CALL :Assign7 "INDEX" "ARG1" "ARG2" "ARG3"
~~~

In the subroutine, the code is substituted into
~~~
CALL :Assign%INDEX% "%ARG1%" "%ARG2%" "%ARG3%"
~~~

When `CALL` command is evaluated, a second substitution changes the code into
~~~
CALL :Assign6 "SRC_VAR" "" "abc"
~~~

The second substitution of the `CALL` command is able to dereference
an environment variable for only one level.
The following code will not work
~~~
:Assign8
  CALL :Assign%%%%%%%~1%%%%%% "%%%%%%%~2%%%%%%"
  EXIT /B
~~~

For example, let's invoke the subroutine like this
~~~
SET INDEX=6
SET PINDEX=INDEX
SET ARG="DST_VAR"
SET PARG=ARG
CALL :Assign8 "PINDEX" "PARG"
~~~

In the subroutine, the code is substituted into
~~~
CALL :Assign%%%PINDEX%%% "%%%PARG%%%"
~~~

When `CALL` command is evaluated, a second substitution substitute
`%PINDEX%` into `INDEX`, and `%%` into `%`. The code becomes
~~~
CALL :Assign%INDEX% "%ARG%"
~~~

However, the substitution process stops here, and an error will be
generated that states

> The system cannot find the batch label specified - Assign%INDEX%.

A good usage of `CALL` command is to use the second substitution to
mimic the behavior of delayed expansion.
~~~
@param %1 The name of the environment variable.
:ValueEcho
  ECHO %~1
  EXIT /B

:DelayedEcho
  SET ARG=1
  CALL :ValueEcho "%%ARG%%"
  SET ARG=2
  CALL :ValueEcho "%%ARG%%"
  EXIT /B
~~~

A powerful usage of `CALL` command is to enable callbacks.
~~~
@param %1 The value combined with tokens separated by ';'.
@param %2 The environment variable holding the name of
          the callback subroutine.
:ValueTokenize
  FOR /F "tokens=1,* delims=;" %%i IN ("%~1") DO (
    CALL :"%%%~2%%" "%%~i"
    IF NOT "%%~j"=="" CALL :ValueTokenize "%%~j" "%~2"
  )
  EXIT /B

@param %1 The value of the token.
:Cb1
  EXIT /B

@param %1 The value of the token.
:Cb2
  EXIT /B

:DoViaCallback
  SET PCALLBCAK=Cb1
  CALL :ValueTokenize "12;34;56" "PCALLBCAK"
  SET PCALLBCAK=Cb2
  CALL :ValueTokenize "12;34;56" "PCALLBCAK"
  EXIT /B
~~~

<h3>3. '%ERRORLEVEL%'</h3>

Notes about using multiple `%ERRORLEVEL%`s.

~~~
:ValueEq
  IF "%~1"=="%~2" ( EXIT /B 1 ) ELSE ( EXIT /B 0 )

:Test1
  CALL :ValueEq "a" "b"
  IF ERRORLEVEL 1 (
    ECHO bad!
  ) ELSE (
    CALL :ValueEq "a" "a"
    IF ERRORLEVEL 1 (
      ECHO ok!
    ) ELSE (
      ECHO bad!
    )
  )
  EXIT /B

:Test2b
  CALL :ValueEq "a" "b"
  IF %ERRORLEVEL% EQU 1 (
    ECHO bad!
  ) ELSE (
    CALL :ValueEq "a" "a"
    IF %ERRORLEVEL% EQU 1 (
      ECHO ok!
    ) ELSE (
      ECHO bad!
    )
  )
  EXIT /B

:Test2
  CALL :ValueEq "a" "b"
  IF %ERRORLEVEL% EQU 1 (
    ECHO bad!
    EXIT /B
  )
  CALL :ValueEq "a" "a"
  IF %ERRORLEVEL% EQU 1 (
    ECHO ok!
  ) ELSE (
    ECHO bad!
  )
  EXIT /B

:Test3b
  CALL :ValueEq "a" "b"
  IF "%ERRORLEVEL%"=="1" (
    ECHO bad!
  ) ELSE (
    CALL :ValueEq "a" "a"
    IF "%ERRORLEVEL%"=="1" (
      ECHO ok!
    ) ELSE (
      ECHO bad!
    )
  )
  EXIT /B

:Test3
  CALL :ValueEq "a" "b"
  IF "%ERRORLEVEL%"=="1" (
    ECHO bad!
    EXIT /B
  )
  CALL :ValueEq "a" "a"
  IF "%ERRORLEVEL%"=="1" (
    ECHO ok!
  ) ELSE (
    ECHO bad!
  )
  EXIT /B
~~~
The subroutines `:Test1`, `:Test2` and `:Test3` are correct.
The subroutines `:Test2b` and `:Test3b` are incorrect.

When using `%ERRORLEVEL%` (macro form), do not put multiple `%ERRORLEVEL%`s
within a single command.
A single command performs macro substitution only once.
In `:Test2b` and `:Test3b`, multiple `%ERRORLEVEL%`s are put within
a single `IF-ELSE` command. When the `ELSE` command block is evaluated,
the `%ERRORLEVEL%` is not substituted again.

`:Test1` doesn't use macro form of `ERRORLEVEL`, thus it doesn't suffer
from this problem.

Also note that, `IF ERRORLEVEL n` means `IF ERRORLEVEL >= n`.
Don't mistake it to be `IF ERRORLEVEL == n`.

