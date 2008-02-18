/*
** 2001 September 15
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
*************************************************************************
** This header file defines the interface that the SQLite library
** presents to client programs.
**
** @(#) $Id$
*/
#ifndef _SQLITE3_H_
#define _SQLITE3_H_
#include <stdarg.h>     /* Needed for the definition of va_list */

/*
** Make sure we can call this stuff from C++.
*/
#ifdef __cplusplus
extern "C" {
#endif

/*
** The version of the SQLite library.
*/
#ifdef SQLITE_VERSION
# undef SQLITE_VERSION
#endif
#define SQLITE_VERSION         "3.3.5"

/*
** The format of the version string is "X.Y.Z<trailing string>", where
** X is the major version number, Y is the minor version number and Z
** is the release number. The trailing string is often "alpha" or "beta".
** For example "3.1.1beta".
**
** The SQLITE_VERSION_NUMBER is an integer with the value 
** (X*100000 + Y*1000 + Z). For example, for version "3.1.1beta", 
** SQLITE_VERSION_NUMBER is set to 3001001. To detect if they are using 
** version 3.1.1 or greater at compile time, programs may use the test 
** (SQLITE_VERSION_NUMBER>=3001001).
*/
#ifdef SQLITE_VERSION_NUMBER
# undef SQLITE_VERSION_NUMBER
#endif
#define SQLITE_VERSION_NUMBER 3003005

/*
** The version string is also compiled into the library so that a program
** can check to make sure that the lib*.a file and the *.h file are from
** the same version.  The sqlite3_libversion() function returns a pointer
** to the sqlite3_version variable - useful in DLLs which cannot access
** global variables.
*/
extern const char sqlite3_version[];
const char *sqlite3_libversion(void);

/*
** Return the value of the SQLITE_VERSION_NUMBER macro when the
** library was compiled.
*/
int sqlite3_libversion_number(void);

/*
** Each open sqlite database is represented by an instance of the
** following opaque structure.
*/
typedef struct sqlite3 sqlite3;


/*
** Some compilers do not support the "long long" datatype.  So we have
** to do a typedef that for 64-bit integers that depends on what compiler
** is being used.
*/
#ifdef SQLITE_INT64_TYPE
  typedef SQLITE_INT64_TYPE sqlite_int64;
  typedef unsigned SQLITE_INT64_TYPE sqlite_uint64;
#elif defined(_MSC_VER) || defined(__BORLANDC__)
  typedef __int64 sqlite_int64;
  typedef unsigned __int64 sqlite_uint64;
#else
  typedef long long int sqlite_int64;
  typedef unsigned long long int sqlite_uint64;
#endif

/*
** If compiling for a processor that lacks floating point support,
** substitute integer for floating-point
*/
#ifdef SQLITE_OMIT_FLOATING_POINT
# define double sqlite_int64
#endif

/*
** A function to close the database.
**
** Call this function with a pointer to a structure that was previously
** returned from sqlite3_open() and the corresponding database will by closed.
**
** All SQL statements prepared using sqlite3_prepare() or
** sqlite3_prepare16() must be deallocated using sqlite3_finalize() before
** this routine is called. Otherwise, SQLITE_BUSY is returned and the
** database connection remains open.
*/
int sqlite3_close(sqlite3 *);

/*
** The type for a callback function.
*/
typedef int (*sqlite3_callback)(void*,int,char**, char**);

/*
** A function to executes one or more statements of SQL.
**
** If one or more of the SQL statements are queries, then
** the callback function specified by the 3rd parameter is
** invoked once for each row of the query result.  This callback
** should normally return 0.  If the callback returns a non-zero
** value then the query is aborted, all subsequent SQL statements
** are skipped and the sqlite3_exec() function returns the SQLITE_ABORT.
**
** The 4th parameter is an arbitrary pointer that is passed
** to the callback function as its first parameter.
**
** The 2nd parameter to the callback function is the number of
** columns in the query result.  The 3rd parameter to the callback
** is an array of strings holding the values for each column.
** The 4th parameter to the callback is an array of strings holding
** the names of each column.
**
** The callback function may be NULL, even for queries.  A NULL
** callback is not an error.  It just means that no callback
** will be invoked.
**
** If an error occurs while parsing or evaluating the SQL (but
** not while executing the callback) then an appropriate error
** message is written into memory obtained from malloc() and
** *errmsg is made to point to that message.  The calling function
** is responsible for freeing the memory that holds the error
** message.   Use sqlite3_free() for this.  If errmsg==NULL,
** then no error message is ever written.
**
** The return value is is SQLITE_OK if there are no errors and
** some other return code if there is an error.  The particular
** return value depends on the type of error. 
**
** If the query could not be executed because a database file is
** locked or busy, then this function returns SQLITE_BUSY.  (This
** behavior can be modified somewhat using the sqlite3_busy_handler()
** and sqlite3_busy_timeout() functions below.)
*/
int sqlite3_exec(
  sqlite3*,                     /* An open database */
  const char *sql,              /* SQL to be executed */
  sqlite3_callback,             /* Callback function */
  void *,                       /* 1st argument to callback function */
  char **errmsg                 /* Error msg written here */
);

/*
** Return values for sqlite3_exec() and sqlite3_step()
*/
#define SQLITE_OK           0   /* Successful result */
/* beginning-of-error-codes */
#define SQLITE_ERROR        1   /* SQL error or missing database */
#define SQLITE_INTERNAL     2   /* NOT USED. Internal logic error in SQLite */
#define SQLITE_PERM         3   /* Access permission denied */
#define SQLITE_ABORT        4   /* Callback routine requested an abort */
#define SQLITE_BUSY         5   /* The database file is locked */
#define SQLITE_LOCKED       6   /* A table in the database is locked */
#define SQLITE_NOMEM        7   /* A malloc() failed */
#define SQLITE_READONLY     8   /* Attempt to write a readonly database */
#define SQLITE_INTERRUPT    9   /* Operation terminated by sqlite3_interrupt()*/
#define SQLITE_IOERR       10   /* Some kind of disk I/O error occurred */
#define SQLITE_CORRUPT     11   /* The database disk image is malformed */
#define SQLITE_NOTFOUND    12   /* NOT USED. Table or record not found */
#define SQLITE_FULL        13   /* Insertion failed because database is full */
#define SQLITE_CANTOPEN    14   /* Unable to open the database file */
#define SQLITE_PROTOCOL    15   /* Database lock protocol error */
#define SQLITE_EMPTY       16   /* Database is empty */
#define SQLITE_SCHEMA      17   /* The database schema changed */
#define SQLITE_TOOBIG      18   /* NOT USED. Too much data for one row */
#define SQLITE_CONSTRAINT  19   /* Abort due to contraint violation */
#define SQLITE_MISMATCH    20   /* Data type mismatch */
#define SQLITE_MISUSE      21   /* Library used incorrectly */
#define SQLITE_NOLFS       22   /* Uses OS features not supported on host */
#define SQLITE_AUTH        23   /* Authorization denied */
#define SQLITE_FORMAT      24   /* Auxiliary database format error */
#define SQLITE_RANGE       25   /* 2nd parameter to sqlite3_bind out of range */
#define SQLITE_NOTADB      26   /* File opened that is not a database file */
#define SQLITE_ROW         100  /* sqlite3_step() has another row ready */
#define SQLITE_DONE        101  /* sqlite3_step() has finished executing */
/* end-of-error-codes */

/*
** Each entry in an SQLite table has a unique integer key.  (The key is
** the value of the INTEGER PRIMARY KEY column if there is such a column,
** otherwise the key is generated at random.  The unique key is always
** available as the ROWID, OID, or _ROWID_ column.)  The following routine
** returns the integer key of the most recent insert in the database.
**
** This function is similar to the mysql_insert_id() function from MySQL.
*/
sqlite_int64 sqlite3_last_insert_rowid(sqlite3*);

/*
** This function returns the number of database rows that were changed
** (or inserted or deleted) by the most recent called sqlite3_exec().
**
** All changes are counted, even if they were later undone by a
** ROLLBACK or ABORT.  Except, changes associated with creating and
** dropping tables are not counted.
**
** If a callback invokes sqlite3_exec() recursively, then the changes
** in the inner, recursive call are counted together with the changes
** in the outer call.
**
** SQLite implements the command "DELETE FROM table" without a WHERE clause
** by dropping and recreating the table.  (This is much faster than going
** through and deleting individual elements form the table.)  Because of
** this optimization, the change count for "DELETE FROM table" will be
** zero regardless of the number of elements that were originally in the
** table. To get an accurate count of the number of rows deleted, use
** "DELETE FROM table WHERE 1" instead.
*/
int sqlite3_changes(sqlite3*);

/*
** This function returns the number of database rows that have been
** modified by INSERT, UPDATE or DELETE statements since the database handle
** was opened. This includes UPDATE, INSERT and DELETE statements executed
** as part of trigger programs. All changes are counted as soon as the
** statement that makes them is completed (when the statement handle is
** passed to sqlite3_reset() or sqlite_finalise()).
**
** SQLite implements the command "DELETE FROM table" without a WHERE clause
** by dropping and recreating the table.  (This is much faster than going
** through and deleting individual elements form the table.)  Because of
** this optimization, the change count for "DELETE FROM table" will be
** zero regardless of the number of elements that were originally in the
** table. To get an accurate count of the number of rows deleted, use
** "DELETE FROM table WHERE 1" instead.
*/
int sqlite3_total_changes(sqlite3*);

/* This function causes any pending database operation to abort and
** return at its earliest opportunity.  This routine is typically
** called in response to a user action such as pressing "Cancel"
** or Ctrl-C where the user wants a long query operation to halt
** immediately.
*/
void sqlite3_interrupt(sqlite3*);


/* These functions return true if the given input string comprises
** one or more complete SQL statements. For the sqlite3_complete() call,
** the parameter must be a nul-terminated UTF-8 string. For
** sqlite3_complete16(), a nul-terminated machine byte order UTF-16 string
** is required.
**
** The algorithm is simple.  If the last token other than spaces
** and comments is a semicolon, then return true.  otherwise return
** false.
*/
int sqlite3_complete(const char *sql);
int sqlite3_complete16(const void *sql);

/*
** This routine identifies a callback function that is invoked
** whenever an attempt is made to open a database table that is
** currently locked by another process or thread.  If the busy callback
** is NULL, then sqlite3_exec() returns SQLITE_BUSY immediately if
** it finds a locked table.  If the busy callback is not NULL, then
** sqlite3_exec() invokes the callback with three arguments.  The
** second argument is the name of the locked table and the third
** argument is the number of times the table has been busy.  If the
** busy callback returns 0, then sqlite3_exec() immediately returns
** SQLITE_BUSY.  If the callback returns non-zero, then sqlite3_exec()
** tries to open the table again and the cycle repeats.
**
** The default busy callback is NULL.
**
** Sqlite is re-entrant, so the busy handler may start a new query. 
** (It is not clear why anyone would every want to do this, but it
** is allowed, in theory.)  But the busy handler may not close the
** database.  Closing the database from a busy handler will delete 
** data structures out from under the executing query and will 
** probably result in a coredump.
*/
int sqlite3_busy_handler(sqlite3*, int(*)(void*,int), void*);

/*
** This routine sets a busy handler that sleeps for a while when a
** table is locked.  The handler will sleep multiple times until 
** at least "ms" milleseconds of sleeping have been done.  After
** "ms" milleseconds of sleeping, the handler returns 0 which
** causes sqlite3_exec() to return SQLITE_BUSY.
**
** Calling this routine with an argument less than or equal to zero
** turns off all busy handlers.
*/
int sqlite3_busy_timeout(sqlite3*, int ms);

/*
** This next routine is really just a wrapper around sqlite3_exec().
** Instead of invoking a user-supplied callback for each row of the
** result, this routine remembers each row of the result in memory
** obtained from malloc(), then returns all of the result after the
** query has finished. 
**
** As an example, suppose the query result where this table:
**
**        Name        | Age
**        -----------------------
**        Alice       | 43
**        Bob         | 28
**        Cindy       | 21
**
** If the 3rd argument were &azResult then after the function returns
** azResult will contain the following data:
**
**        azResult[0] = "Name";
**        azResult[1] = "Age";
**        azResult[2] = "Alice";
**        azResult[3] = "43";
**        azResult[4] = "Bob";
**        azResult[5] = "28";
**        azResult[6] = "Cindy";
**        azResult[7] = "21";
**
** Notice that there is an extra row of data containing the column
** headers.  But the *nrow return value is still 3.  *ncolumn is
** set to 2.  In general, the number of values inserted into azResult
** will be ((*nrow) + 1)*(*ncolumn).
**
** After the calling function has finished using the result, it should 
** pass the result data pointer to sqlite3_free_table() in order to 
** release the memory that was malloc-ed.  Because of the way the 
** malloc() happens, the calling function must not try to call 
** free() directly.  Only sqlite3_free_table() is able to release 
** the memory properly and safely.
**
** The return value of this routine is the same as from sqlite3_exec().
*/
int sqlite3_get_table(
  sqlite3*,               /* An open database */
  const char *sql,       /* SQL to be executed */
  char ***resultp,       /* Result written to a char *[]  that this points to */
  int *nrow,             /* Number of result rows written here */
  int *ncolumn,          /* Number of result columns written here */
  char **errmsg          /* Error msg written here */
);

/*
** Call this routine to free the memory that sqlite3_get_table() allocated.
*/
void sqlite3_free_table(char **result);

/*
** The following routines are variants of the "sprintf()" from the
** standard C library.  The resulting string is written into memory
** obtained from malloc() so that there is never a possiblity of buffer
** overflow.  These routines also implement some additional formatting
** options that are useful for constructing SQL statements.
**
** The strings returned by these routines should be freed by calling
** sqlite3_free().
**
** All of the usual printf formatting options apply.  In addition, there
** is a "%q" option.  %q works like %s in that it substitutes a null-terminated
** string from the argument list.  But %q also doubles every '\'' character.
** %q is designed for use inside a string literal.  By doubling each '\''
** character it escapes that character and allows it to be inserted into
** the string.
**
** For example, so some string variable contains text as follows:
**
**      char *zText = "It's a happy day!";
**
** We can use this text in an SQL statement as follows:
**
**      char *z = sqlite3_mprintf("INSERT INTO TABLES('%q')", zText);
**      sqlite3_exec(db, z, callback1, 0, 0);
**      sqlite3_free(z);
**
** Because the %q format string is used, the '\'' character in zText
** is escaped and the SQL generated is as follows:
**
**      INSERT INTO table1 VALUES('It''s a happy day!')
**
** This is correct.  Had we used %s instead of %q, the generated SQL
** would have looked like this:
**
**      INSERT INTO table1 VALUES('It's a happy day!');
**
** This second example is an SQL syntax error.  As a general rule you
** should always use %q instead of %s when inserting text into a string 
** literal.
*/
char *sqlite3_mprintf(const char*,...);
char *sqlite3_vmprintf(const char*, va_list);
void sqlite3_free(char *z);
char *sqlite3_snprintf(int,char*,const char*, ...);

#ifndef SQLITE_OMIT_AUTHORIZATION
/*
** This routine registers a callback with the SQLite library.  The
** callback is invoked (at compile-time, not at run-time) for each
** attempt to access a column of a table in the database.  The callback
** returns SQLITE_OK if access is allowed, SQLITE_DENY if the entire
** SQL statement should be aborted with an error and SQLITE_IGNORE
** if the column should be treated as a NULL value.
*/
int sqlite3_set_authorizer(
  sqlite3*,
  int (*xAuth)(void*,int,const char*,const char*,const char*,const char*),
  void *pUserData
);
#endif

/*
** The second parameter to the access authorization function above will
** be one of the values below.  These values signify what kind of operation
** is to be authorized.  The 3rd and 4th parameters to the authorization
** function will be parameters or NULL depending on which of the following
** codes is used as the second parameter.  The 5th parameter is the name
** of the database ("main", "temp", etc.) if applicable.  The 6th parameter
** is the name of the inner-most trigger or view that is responsible for
** the access attempt or NULL if this access attempt is directly from 
** input SQL code.
**
**                                          Arg-3           Arg-4
*/
#define SQLITE_COPY                  0   /* Table Name      File Name       */
#define SQLITE_CREATE_INDEX          1   /* Index Name      Table Name      */
#define SQLITE_CREATE_TABLE          2   /* Table Name      NULL            */
#define SQLITE_CREATE_TEMP_INDEX     3   /* Index Name      Table Name      */
#define SQLITE_CREATE_TEMP_TABLE     4   /* Table Name      NULL            */
#define SQLITE_CREATE_TEMP_TRIGGER   5   /* Trigger Name    Table Name      */
#define SQLITE_CREATE_TEMP_VIEW      6   /* View Name       NULL            */
#define SQLITE_CREATE_TRIGGER        7   /* Trigger Name    Table Name      */
#define SQLITE_CREATE_VIEW           8   /* View Name       NULL            */
#define SQLITE_DELETE                9   /* Table Name      NULL            */
#define SQLITE_DROP_INDEX           10   /* Index Name      Table Name      */
#define SQLITE_DROP_TABLE           11   /* Table Name      NULL            */
#define SQLITE_DROP_TEMP_INDEX      12   /* Index Name      Table Name      */
#define SQLITE_DROP_TEMP_TABLE      13   /* Table Name      NULL            */
#define SQLITE_DROP_TEMP_TRIGGER    14   /* Trigger Name    Table Name      */
#define SQLITE_DROP_TEMP_VIEW       15   /* View Name       NULL            */
#define SQLITE_DROP_TRIGGER         16   /* Trigger Name    Table Name      */
#define SQLITE_DROP_VIEW            17   /* View Name       NULL            */
#define SQLITE_INSERT               18   /* Table Name      NULL            */
#define SQLITE_PRAGMA               19   /* Pragma Name     1st arg or NULL */
#define SQLITE_READ                 20   /* Table Name      Column Name     */
#define SQLITE_SELECT               21   /* NULL            NULL            */
#define SQLITE_TRANSACTION          22   /* NULL            NULL            */
#define SQLITE_UPDATE               23   /* Table Name      Column Name     */
#define SQLITE_ATTACH               24   /* Filename        NULL            */
#define SQLITE_DETACH               25   /* Database Name   NULL            */
#define SQLITE_ALTER_TABLE          26   /* Database Name   Table Name      */
#define SQLITE_REINDEX              27   /* Index Name      NULL            */
#define SQLITE_ANALYZE              28   /* Table Name      NULL            */


/*
** The return value of the authorization function should be one of the
** following constants:
*/
/* #define SQLITE_OK  0   // Allow access (This is actually defined above) */
#define SQLITE_DENY   1   /* Abort the SQL statement with an error */
#define SQLITE_IGNORE 2   /* Don't allow access, but don't generate an error */

/*
** Register a function for tracing SQL command evaluation.  The function
** registered by sqlite3_trace() is invoked at the first sqlite3_step()
** for the evaluation of an SQL statement.  The function registered by
** sqlite3_profile() runs at the end of each SQL statement and includes
** information on how long that statement ran.
**
** The sqlite3_profile() API is currently considered experimental and
** is subject to change.
*/
void *sqlite3_trace(sqlite3*, void(*xTrace)(void*,const char*), void*);
void *sqlite3_profile(sqlite3*,
   void(*xProfile)(void*,const char*,sqlite_uint64), void*);

/*
** This routine configures a callback function - the progress callback - that
** is invoked periodically during long running calls to sqlite3_exec(),
** sqlite3_step() and sqlite3_get_table(). An example use for this API is to 
** keep a GUI updated during a large query.
**
** The progress callback is invoked once for every N virtual machine opcodes,
** where N is the second argument to this function. The progress callback
** itself is identified by the third argument to this function. The fourth
** argument to this function is a void pointer passed to the progress callback
** function each time it is invoked.
**
** If a call to sqlite3_exec(), sqlite3_step() or sqlite3_get_table() results 
** in less than N opcodes being executed, then the progress callback is not
** invoked.
** 
** To remove the progress callback altogether, pass NULL as the third
** argument to this function.
**
** If the progress callback returns a result other than 0, then the current 
** query is immediately terminated and any database changes rolled back. If the
** query was part of a larger transaction, then the transaction is not rolled
** back and remains active. The sqlite3_exec() call returns SQLITE_ABORT. 
**
******* THIS IS AN EXPERIMENTAL API AND IS SUBJECT TO CHANGE ******
*/
void sqlite3_progress_handler(sqlite3*, int, int(*)(void*), void*);

/*
** Register a callback function to be invoked whenever a new transaction
** is committed.  The pArg argument is passed through to the callback.
** callback.  If the callback function returns non-zero, then the commit
** is converted into a rollback.
**
** If another function was previously registered, its pArg value is returned.
** Otherwise NULL is returned.
**
** Registering a NULL function disables the callback.
**
******* THIS IS AN EXPERIMENTAL API AND IS SUBJECT TO CHANGE ******
*/
void *sqlite3_commit_hook(sqlite3*, int(*)(void*), void*);

/*
** Open the sqlite database file "filename".  The "filename" is UTF-8
** encoded for sqlite3_open() and UTF-16 encoded in the native byte order
** for sqlite3_open16().  An sqlite3* handle is returned in *ppDb, even
** if an error occurs. If the database is opened (or created) successfully,
** then SQLITE_OK is returned. Otherwise an error code is returned. The
** sqlite3_errmsg() or sqlite3_errmsg16()  routines can be used to obtain
** an English language description of the error.
**
** If the database file does not exist, then a new database is created.
** The encoding for the database is UTF-8 if sqlite3_open() is called and
** UTF-16 if sqlite3_open16 is used.
**
** Whether or not an error occurs when it is opened, resources associated
** with the sqlite3* handle should be released by passing it to
** sqlite3_close() when it is no longer required.
*/
int sqlite3_open(
  const char *filename,   /* Database filename (UTF-8) */
  sqlite3 **ppDb          /* OUT: SQLite db handle */
);
int sqlite3_open16(
  const void *filename,   /* Database filename (UTF-16) */
  sqlite3 **ppDb          /* OUT: SQLite db handle */
);

/*
** Return the error code for the most recent sqlite3_* API call associated
** with sqlite3 handle 'db'. SQLITE_OK is returned if the most recent 
** API call was successful.
**
** Calls to many sqlite3_* functions set the error code and string returned
** by sqlite3_errcode(), sqlite3_errmsg() and sqlite3_errmsg16()
** (overwriting the previous values). Note that calls to sqlite3_errcode(),
** sqlite3_errmsg() and sqlite3_errmsg16() themselves do not affect the
** results of future invocations.
**
** Assuming no other intervening sqlite3_* API calls are made, the error
** code returned by this function is associated with the same error as
** the strings  returned by sqlite3_errmsg() and sqlite3_errmsg16().
*/
int sqlite3_errcode(sqlite3 *db);

/*
** Return a pointer to a UTF-8 encoded string describing in english the
** error condition for the most recent sqlite3_* API call. The returned
** string is always terminated by an 0x00 byte.
**
** The string "not an error" is returned when the most recent API call was
** successful.
*/
const char *sqlite3_errmsg(sqlite3*);

/*
** Return a pointer to a UTF-16 native byte order encoded string describing
** in english the error condition for the most recent sqlite3_* API call.
** The returned string is always terminated by a pair of 0x00 bytes.
**
** The string "not an error" is returned when the most recent API call was
** successful.
*/
const void *sqlite3_errmsg16(sqlite3*);

/*
** An instance of the following opaque structure is used to represent
** a compiled SQL statment.
*/
typedef struct sqlite3_stmt sqlite3_stmt;

/*
** To execute an SQL query, it must first be compiled into a byte-code
** program using one of the following routines. The only difference between
** them is that the second argument, specifying the SQL statement to
** compile, is assumed to be encoded in UTF-8 for the sqlite3_prepare()
** function and UTF-16 for sqlite3_prepare16().
**
** The first parameter "db" is an SQLite database handle. The second
** parameter "zSql" is the statement to be compiled, encoded as either
** UTF-8 or UTF-16 (see above). If the next parameter, "nBytes", is less
** than zero, then zSql is read up to the first nul terminator.  If
** "nBytes" is not less than zero, then it is the length of the string zSql
** in bytes (not characters).
**
** *pzTail is made to point to the first byte past the end of the first
** SQL statement in zSql.  This routine only compiles the first statement
** in zSql, so *pzTail is left pointing to what remains uncompiled.
**
** *ppStmt is left pointing to a compiled SQL statement that can be
** executed using sqlite3_step().  Or if there is an error, *ppStmt may be
** set to NULL.  If the input text contained no SQL (if the input is and
** empty string or a comment) then *ppStmt is set to NULL.
**
** On success, SQLITE_OK is returned.  Otherwise an error code is returned.
*/
int sqlite3_prepare(
  sqlite3 *db,            /* Database handle */
  const char *zSql,       /* SQL statement, UTF-8 encoded */
  int nBytes,             /* Length of zSql in bytes. */
  sqlite3_stmt **ppStmt,  /* OUT: Statement handle */
  const char **pzTail     /* OUT: Pointer to unused portion of zSql */
);
int sqlite3_prepare16(
  sqlite3 *db,            /* Database handle */
  const void *zSql,       /* SQL statement, UTF-16 encoded */
  int nBytes,             /* Length of zSql in bytes. */
  sqlite3_stmt **ppStmt,  /* OUT: Statement handle */
  const void **pzTail     /* OUT: Pointer to unused portion of zSql */
);

/*
** Pointers to the following two opaque structures are used to communicate
** with the implementations of user-defined functions.
*/
typedef struct sqlite3_context sqlite3_context;
typedef struct Mem sqlite3_value;

/*
** In the SQL strings input to sqlite3_prepare() and sqlite3_prepare16(),
** one or more literals can be replace by parameters "?" or ":AAA" or
** "$VVV" where AAA is an identifer and VVV is a variable name according
** to the syntax rules of the TCL programming language.
** The value of these parameters (also called "host parameter names") can
** be set using the routines listed below.
**
** In every case, the first parameter is a pointer to the sqlite3_stmt
** structure returned from sqlite3_prepare().  The second parameter is the
** index of the parameter.  The first parameter as an index of 1.  For
** named parameters (":AAA" or "$VVV") you can use 
** sqlite3_bind_parameter_index() to get the correct index value given
** the parameters name.  If the same named parameter occurs more than
** once, it is assigned the same index each time.
**
** The fifth parameter to sqlite3_bind_blob(), sqlite3_bind_text(), and
** sqlite3_bind_text16() is a destructor used to dispose of the BLOB or
** text after SQLite has finished with it.  If the fifth argument is the
** special value SQLITE_STATIC, then the library assumes that the information
** is in static, unmanaged space and does not need to be freed.  If the
** fifth argument has the value SQLITE_TRANSIENT, then SQLite makes its
** own private copy of the data.
**
** The sqlite3_bind_* routine must be called before sqlite3_step() after
** an sqlite3_prepare() or sqlite3_reset().  Unbound parameterss are
** interpreted as NULL.
*/
int sqlite3_bind_blob(sqlite3_stmt*, int, const void*, int n, void(*)(void*));
int sqlite3_bind_double(sqlite3_stmt*, int, double);
int sqlite3_bind_int(sqlite3_stmt*, int, int);
int sqlite3_bind_int64(sqlite3_stmt*, int, sqlite_int64);
int sqlite3_bind_null(sqlite3_stmt*, int);
int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
int sqlite3_bind_text16(sqlite3_stmt*, int, const void*, int, void(*)(void*));
int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);

/*
** Return the number of parameters in a compiled SQL statement.  This
** routine was added to support DBD::SQLite.
*/
int sqlite3_bind_parameter_count(sqlite3_stmt*);

/*
** Return the name of the i-th parameter.  Ordinary parameters "?" are
** nameless and a NULL is returned.  For parameters of the form :AAA or
** $VVV the complete text of the parameter name is returned, including
** the initial ":" or "$".  NULL is returned if the index is out of range.
*/
const char *sqlite3_bind_parameter_name(sqlite3_stmt*, int);

/*
** Return the index of a parameter with the given name.  The name
** must match exactly.  If no parameter with the given name is found,
** return 0.
*/
int sqlite3_bind_parameter_index(sqlite3_stmt*, const char *zName);

/*
** Set all the parameters in the compiled SQL statement to NULL.
*/
int sqlite3_clear_bindings(sqlite3_stmt*);

/*
** Return the number of columns in the result set returned by the compiled
** SQL statement. This routine returns 0 if pStmt is an SQL statement
** that does not return data (for example an UPDATE).
*/
int sqlite3_column_count(sqlite3_stmt *pStmt);

/*
** The first parameter is a compiled SQL statement. This function returns
** the column heading for the Nth column of that statement, where N is the
** second function parameter.  The string returned is UTF-8 for
** sqlite3_column_name() and UTF-16 for sqlite3_column_name16().
*/
const char *sqlite3_column_name(sqlite3_stmt*,int);
const void *sqlite3_column_name16(sqlite3_stmt*,int);

/*
** The first parameter to the following calls is a compiled SQL statement.
** These functions return information about the Nth column returned by 
** the statement, where N is the second function argument.
**
** If the Nth column returned by the statement is not a column value,
** then all of the functions return NULL. Otherwise, the return the 
** name of the attached database, table and column that the expression
** extracts a value from.
**
** As with all other SQLite APIs, those postfixed with "16" return UTF-16
** encoded strings, the other functions return UTF-8. The memory containing
** the returned strings is valid until the statement handle is finalized().
**
** These APIs are only available if the library was compiled with the 
** SQLITE_ENABLE_COLUMN_METADATA preprocessor symbol defined.
*/
const char *sqlite3_column_database_name(sqlite3_stmt*,int);
const void *sqlite3_column_database_name16(sqlite3_stmt*,int);
const char *sqlite3_column_table_name(sqlite3_stmt*,int);
const void *sqlite3_column_table_name16(sqlite3_stmt*,int);
const char *sqlite3_column_origin_name(sqlite3_stmt*,int);
const void *sqlite3_column_origin_name16(sqlite3_stmt*,int);

/*
** The first parameter is a compiled SQL statement. If this statement
** is a SELECT statement, the Nth column of the returned result set 
** of the SELECT is a table column then the declared type of the table
** column is returned. If the Nth column of the result set is not at table
** column, then a NULL pointer is returned. The returned string is always
** UTF-8 encoded. For example, in the database schema:
**
** CREATE TABLE t1(c1 VARIANT);
**
** And the following statement compiled:
**
** SELECT c1 + 1, c1 FROM t1;
**
** Then this routine would return the string "VARIANT" for the second
** result column (i==1), and a NULL pointer for the first result column
** (i==0).
*/
const char *sqlite3_column_decltype(sqlite3_stmt *, int i);

/*
** The first parameter is a compiled SQL statement. If this statement
** is a SELECT statement, the Nth column of the returned result set 
** of the SELECT is a table column then the declared type of the table
** column is returned. If the Nth column of the result set is not at table
** column, then a NULL pointer is returned. The returned string is always
** UTF-16 encoded. For example, in the database schema:
**
** CREATE TABLE t1(c1 INTEGER);
**
** And the following statement compiled:
**
** SELECT c1 + 1, c1 FROM t1;
**
** Then this routine would return the string "INTEGER" for the second
** result column (i==1), and a NULL pointer for the first result column
** (i==0).
*/
const void *sqlite3_column_decltype16(sqlite3_stmt*,int);

/* 
** After an SQL query has been compiled with a call to either
** sqlite3_prepare() or sqlite3_prepare16(), then this function must be
** called one or more times to execute the statement.
**
** The return value will be either SQLITE_BUSY, SQLITE_DONE, 
** SQLITE_ROW, SQLITE_ERROR, or SQLITE_MISUSE.
**
** SQLITE_BUSY means that the database engine attempted to open
** a locked database and there is no busy callback registered.
** Call sqlite3_step() again to retry the open.
**
** SQLITE_DONE means that the statement has finished executing
** successfully.  sqlite3_step() should not be called again on this virtual
** machine.
**
** If the SQL statement being executed returns any data, then 
** SQLITE_ROW is returned each time a new row of data is ready
** for processing by the caller. The values may be accessed using
** the sqlite3_column_*() functions described below. sqlite3_step()
** is called again to retrieve the next row of data.
** 
** SQLITE_ERROR means that a run-time error (such as a constraint
** violation) has occurred.  sqlite3_step() should not be called again on
** the VM. More information may be found by calling sqlite3_errmsg().
**
** SQLITE_MISUSE means that the this routine was called inappropriately.
** Perhaps it was called on a virtual machine that had already been
** finalized or on one that had previously returned SQLITE_ERROR or
** SQLITE_DONE.  Or it could be the case the the same database connection
** is being used simulataneously by two or more threads.
*/
int sqlite3_step(sqlite3_stmt*);

/*
** Return the number of values in the current row of the result set.
**
** After a call to sqlite3_step() that returns SQLITE_ROW, this routine
** will return the same value as the sqlite3_column_count() function.
** After sqlite3_step() has returned an SQLITE_DONE, SQLITE_BUSY or
** error code, or before sqlite3_step() has been called on a 
** compiled SQL statement, this routine returns zero.
*/
int sqlite3_data_count(sqlite3_stmt *pStmt);

/*
** Values are stored in the database in one of the following fundamental
** types.
*/
#define SQLITE_INTEGER  1
#define SQLITE_FLOAT    2
/* #define SQLITE_TEXT  3  // See below */
#define SQLITE_BLOB     4
#define SQLITE_NULL     5

/*
** SQLite version 2 defines SQLITE_TEXT differently.  To allow both
** version 2 and version 3 to be included, undefine them both if a
** conflict is seen.  Define SQLITE3_TEXT to be the version 3 value.
*/
#ifdef SQLITE_TEXT
# undef SQLITE_TEXT
#else
# define SQLITE_TEXT     3
#endif
#define SQLITE3_TEXT     3

/*
** The next group of routines returns information about the information
** in a single column of the current result row of a query.  In every
** case the first parameter is a pointer to the SQL statement that is being
** executed (the sqlite_stmt* that was returned from sqlite3_prepare()) and
** the second argument is the index of the column for which information 
** should be returned.  iCol is zero-indexed.  The left-most column as an
** index of 0.
**
** If the SQL statement is not currently point to a valid row, or if the
** the colulmn index is out of range, the result is undefined.
**
** These routines attempt to convert the value where appropriate.  For
** example, if the internal representation is FLOAT and a text result
** is requested, sprintf() is used internally to do the conversion
** automatically.  The following table details the conversions that
** are applied:
**
**    Internal Type    Requested Type     Conversion
**    -------------    --------------    --------------------------
**       NULL             INTEGER         Result is 0
**       NULL             FLOAT           Result is 0.0
**       NULL             TEXT            Result is an empty string
**       NULL             BLOB            Result is a zero-length BLOB
**       INTEGER          FLOAT           Convert from integer to float
**       INTEGER          TEXT            ASCII rendering of the integer
**       INTEGER          BLOB            Same as for INTEGER->TEXT
**       FLOAT            INTEGER         Convert from float to integer
**       FLOAT            TEXT            ASCII rendering of the float
**       FLOAT            BLOB            Same as FLOAT->TEXT
**       TEXT             INTEGER         Use atoi()
**       TEXT             FLOAT           Use atof()
**       TEXT             BLOB            No change
**       BLOB             INTEGER         Convert to TEXT then use atoi()
**       BLOB             FLOAT           Convert to TEXT then use atof()
**       BLOB             TEXT            Add a \000 terminator if needed
**
** The following access routines are provided:
**
** _type()     Return the datatype of the result.  This is one of
**             SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB,
**             or SQLITE_NULL.
** _blob()     Return the value of a BLOB.
** _bytes()    Return the number of bytes in a BLOB value or the number
**             of bytes in a TEXT value represented as UTF-8.  The \000
**             terminator is included in the byte count for TEXT values.
** _bytes16()  Return the number of bytes in a BLOB value or the number
**             of bytes in a TEXT value represented as UTF-16.  The \u0000
**             terminator is included in the byte count for TEXT values.
** _double()   Return a FLOAT value.
** _int()      Return an INTEGER value in the host computer's native
**             integer representation.  This might be either a 32- or 64-bit
**             integer depending on the host.
** _int64()    Return an INTEGER value as a 64-bit signed integer.
** _text()     Return the value as UTF-8 text.
** _text16()   Return the value as UTF-16 text.
*/
const void *sqlite3_column_blob(sqlite3_stmt*, int iCol);
int sqlite3_column_bytes(sqlite3_stmt*, int iCol);
int sqlite3_column_bytes16(sqlite3_stmt*, int iCol);
double sqlite3_column_double(sqlite3_stmt*, int iCol);
int sqlite3_column_int(sqlite3_stmt*, int iCol);
sqlite_int64 sqlite3_column_int64(sqlite3_stmt*, int iCol);
const unsigned char *sqlite3_column_text(sqlite3_stmt*, int iCol);
const void *sqlite3_column_text16(sqlite3_stmt*, int iCol);
int sqlite3_column_type(sqlite3_stmt*, int iCol);
int sqlite3_column_numeric_type(sqlite3_stmt*, int iCol);

/*
** The sqlite3_finalize() function is called to delete a compiled
** SQL statement obtained by a previous call to sqlite3_prepare()
** or sqlite3_prepare16(). If the statement was executed successfully, or
** not executed at all, then SQLITE_OK is returned. If execution of the
** statement failed then an error code is returned. 
**
** This routine can be called at any point during the execution of the
** virtual machine.  If the virtual machine has not completed execution
** when this routine is called, that is like encountering an error or
** an interrupt.  (See sqlite3_interrupt().)  Incomplete updates may be
** rolled back and transactions cancelled,  depending on the circumstances,
** and the result code returned will be SQLITE_ABORT.
*/
int sqlite3_finalize(sqlite3_stmt *pStmt);

/*
** The sqlite3_reset() function is called to reset a compiled SQL
** statement obtained by a previous call to sqlite3_prepare() or
** sqlite3_prepare16() back to it's initial state, ready to be re-executed.
** Any SQL statement variables that had values bound to them using
** the sqlite3_bind_*() API retain their values.
*/
int sqlite3_reset(sqlite3_stmt *pStmt);

/*
** The following two functions are used to add user functions or aggregates
** implemented in C to the SQL langauge interpreted by SQLite. The
** difference only between the two is that the second parameter, the
** name of the (scalar) function or aggregate, is encoded in UTF-8 for
** sqlite3_create_function() and UTF-16 for sqlite3_create_function16().
**
** The first argument is the database handle that the new function or
** aggregate is to be added to. If a single program uses more than one
** database handle internally, then user functions or aggregates must 
** be added individually to each database handle with which they will be
** used.
**
** The third parameter is the number of arguments that the function or
** aggregate takes. If this parameter is negative, then the function or
** aggregate may take any number of arguments.
**
** The fourth parameter is one of SQLITE_UTF* values defined below,
** indicating the encoding that the function is most likely to handle
** values in.  This does not change the behaviour of the programming
** interface. However, if two versions of the same function are registered
** with different encoding values, SQLite invokes the version likely to
** minimize conversions between text encodings.
**
** The seventh, eighth and ninth parameters, xFunc, xStep and xFinal, are
** pointers to user implemented C functions that implement the user
** function or aggregate. A scalar function requires an implementation of
** the xFunc callback only, NULL pointers should be passed as the xStep
** and xFinal parameters. An aggregate function requires an implementation
** of xStep and xFinal, but NULL should be passed for xFunc. To delete an
** existing user function or aggregate, pass NULL for all three function
** callback. Specifying an inconstent set of callback values, such as an
** xFunc and an xFinal, or an xStep but no xFinal, SQLITE_ERROR is
** returned.
*/
int sqlite3_create_function(
  sqlite3 *,
  const char *zFunctionName,
  int nArg,
  int eTextRep,
  void*,
  void (*xFunc)(sqlite3_context*,int,sqlite3_value**),
  void (*xStep)(sqlite3_context*,int,sqlite3_value**),
  void (*xFinal)(sqlite3_context*)
);
int sqlite3_create_function16(
  sqlite3*,
  const void *zFunctionName,
  int nArg,
  int eTextRep,
  void*,
  void (*xFunc)(sqlite3_context*,int,sqlite3_value**),
  void (*xStep)(sqlite3_context*,int,sqlite3_value**),
  void (*xFinal)(sqlite3_context*)
);

/*
** This function is deprecated.  Do not use it.  It continues to exist
** so as not to break legacy code.  But new code should avoid using it.
*/
int sqlite3_aggregate_count(sqlite3_context*);

/*
** The next group of routines returns information about parameters to
** a user-defined function.  Function implementations use these routines
** to access their parameters.  These routines are the same as the
** sqlite3_column_* routines except that these routines take a single
** sqlite3_value* pointer instead of an sqlite3_stmt* and an integer
** column number.
*/
const void *sqlite3_value_blob(sqlite3_value*);
int sqlite3_value_bytes(sqlite3_value*);
int sqlite3_value_bytes16(sqlite3_value*);
double sqlite3_value_double(sqlite3_value*);
int sqlite3_value_int(sqlite3_value*);
sqlite_int64 sqlite3_value_int64(sqlite3_value*);
const unsigned char *sqlite3_value_text(sqlite3_value*);
const void *sqlite3_value_text16(sqlite3_value*);
const void *sqlite3_value_text16le(sqlite3_value*);
const void *sqlite3_value_text16be(sqlite3_value*);
int sqlite3_value_type(sqlite3_value*);
int sqlite3_value_numeric_type(sqlite3_value*);

/*
** Aggregate functions use the following routine to allocate
** a structure for storing their state.  The first time this routine
** is called for a particular aggregate, a new structure of size nBytes
** is allocated, zeroed, and returned.  On subsequent calls (for the
** same aggregate instance) the same buffer is returned.  The implementation
** of the aggregate can use the returned buffer to accumulate data.
**
** The buffer allocated is freed automatically by SQLite.
*/
void *sqlite3_aggregate_context(sqlite3_context*, int nBytes);

/*
** The pUserData parameter to the sqlite3_create_function()
** routine used to register user functions is available to
** the implementation of the function using this call.
*/
void *sqlite3_user_data(sqlite3_context*);

/*
** The following two functions may be used by scalar user functions to
** associate meta-data with argument values. If the same value is passed to
** multiple invocations of the user-function during query execution, under
** some circumstances the associated meta-data may be preserved. This may
** be used, for example, to add a regular-expression matching scalar
** function. The compiled version of the regular expression is stored as
** meta-data associated with the SQL value passed as the regular expression
** pattern.
**
** Calling sqlite3_get_auxdata() returns a pointer to the meta data
** associated with the Nth argument value to the current user function
** call, where N is the second parameter. If no meta-data has been set for
** that value, then a NULL pointer is returned.
**
** The sqlite3_set_auxdata() is used to associate meta data with a user
** function argument. The third parameter is a pointer to the meta data
** to be associated with the Nth user function argument value. The fourth
** parameter specifies a 'delete function' that will be called on the meta
** data pointer to release it when it is no longer required. If the delete
** function pointer is NULL, it is not invoked.
**
** In practice, meta-data is preserved between function calls for
** expressions that are constant at compile time. This includes literal
** values and SQL variables.
*/
void *sqlite3_get_auxdata(sqlite3_context*, int);
void sqlite3_set_auxdata(sqlite3_context*, int, void*, void (*)(void*));


/*
** These are special value for the destructor that is passed in as the
** final argument to routines like sqlite3_result_blob().  If the destructor
** argument is SQLITE_STATIC, it means that the content pointer is constant
** and will never change.  It does not need to be destroyed.  The 
** SQLITE_TRANSIENT value means that the content will likely change in
** the near future and that SQLite should make its own private copy of
** the content before returning.
*/
#define SQLITE_STATIC      ((void(*)(void *))0)
#define SQLITE_TRANSIENT   ((void(*)(void *))-1)

/*
** User-defined functions invoke the following routines in order to
** set their return value.
*/
void sqlite3_result_blob(sqlite3_context*, const void*, int, void(*)(void*));
void sqlite3_result_double(sqlite3_context*, double);
void sqlite3_result_error(sqlite3_context*, const char*, int);
void sqlite3_result_error16(sqlite3_context*, const void*, int);
void sqlite3_result_int(sqlite3_context*, int);
void sqlite3_result_int64(sqlite3_context*, sqlite_int64);
void sqlite3_result_null(sqlite3_context*);
void sqlite3_result_text(sqlite3_context*, const char*, int, void(*)(void*));
void sqlite3_result_text16(sqlite3_context*, const void*, int, void(*)(void*));
void sqlite3_result_text16le(sqlite3_context*, const void*, int,void(*)(void*));
void sqlite3_result_text16be(sqlite3_context*, const void*, int,void(*)(void*));
void sqlite3_result_value(sqlite3_context*, sqlite3_value*);

/*
** These are the allowed values for the eTextRep argument to
** sqlite3_create_collation and sqlite3_create_function.
*/
#define SQLITE_UTF8           1
#define SQLITE_UTF16LE        2
#define SQLITE_UTF16BE        3
#define SQLITE_UTF16          4    /* Use native byte order */
#define SQLITE_ANY            5    /* sqlite3_create_function only */
#define SQLITE_UTF16_ALIGNED  8    /* sqlite3_create_collation only */

/*
** These two functions are used to add new collation sequences to the
** sqlite3 handle specified as the first argument. 
**
** The name of the new collation sequence is specified as a UTF-8 string
** for sqlite3_create_collation() and a UTF-16 string for
** sqlite3_create_collation16(). In both cases the name is passed as the
** second function argument.
**
** The third argument must be one of the constants SQLITE_UTF8,
** SQLITE_UTF16LE or SQLITE_UTF16BE, indicating that the user-supplied
** routine expects to be passed pointers to strings encoded using UTF-8,
** UTF-16 little-endian or UTF-16 big-endian respectively.
**
** A pointer to the user supplied routine must be passed as the fifth
** argument. If it is NULL, this is the same as deleting the collation
** sequence (so that SQLite cannot call it anymore). Each time the user
** supplied function is invoked, it is passed a copy of the void* passed as
** the fourth argument to sqlite3_create_collation() or
** sqlite3_create_collation16() as its first parameter.
**
** The remaining arguments to the user-supplied routine are two strings,
** each represented by a [length, data] pair and encoded in the encoding
** that was passed as the third argument when the collation sequence was
** registered. The user routine should return negative, zero or positive if
** the first string is less than, equal to, or greater than the second
** string. i.e. (STRING1 - STRING2).
*/
int sqlite3_create_collation(
  sqlite3*, 
  const char *zName, 
  int eTextRep, 
  void*,
  int(*xCompare)(void*,int,const void*,int,const void*)
);
int sqlite3_create_collation16(
  sqlite3*, 
  const char *zName, 
  int eTextRep, 
  void*,
  int(*xCompare)(void*,int,const void*,int,const void*)
);

/*
** To avoid having to register all collation sequences before a database
** can be used, a single callback function may be registered with the
** database handle to be called whenever an undefined collation sequence is
** required.
**
** If the function is registered using the sqlite3_collation_needed() API,
** then it is passed the names of undefined collation sequences as strings
** encoded in UTF-8. If sqlite3_collation_needed16() is used, the names
** are passed as UTF-16 in machine native byte order. A call to either
** function replaces any existing callback.
**
** When the user-function is invoked, the first argument passed is a copy
** of the second argument to sqlite3_collation_needed() or
** sqlite3_collation_needed16(). The second argument is the database
** handle. The third argument is one of SQLITE_UTF8, SQLITE_UTF16BE or
** SQLITE_UTF16LE, indicating the most desirable form of the collation
** sequence function required. The fourth parameter is the name of the
** required collation sequence.
**
** The collation sequence is returned to SQLite by a collation-needed
** callback using the sqlite3_create_collation() or
** sqlite3_create_collation16() APIs, described above.
*/
int sqlite3_collation_needed(
  sqlite3*, 
  void*, 
  void(*)(void*,sqlite3*,int eTextRep,const char*)
);
int sqlite3_collation_needed16(
  sqlite3*, 
  void*,
  void(*)(void*,sqlite3*,int eTextRep,const void*)
);

/*
** Specify the key for an encrypted database.  This routine should be
** called right after sqlite3_open().
**
** The code to implement this API is not available in the public release
** of SQLite.
*/
int sqlite3_key(
  sqlite3 *db,                   /* Database to be rekeyed */
  const void *pKey, int nKey     /* The key */
);

/*
** Change the key on an open database.  If the current database is not
** encrypted, this routine will encrypt it.  If pNew==0 or nNew==0, the
** database is decrypted.
**
** The code to implement this API is not available in the public release
** of SQLite.
*/
int sqlite3_rekey(
  sqlite3 *db,                   /* Database to be rekeyed */
  const void *pKey, int nKey     /* The new key */
);

/*
** Sleep for a little while. The second parameter is the number of
** miliseconds to sleep for. 
**
** If the operating system does not support sleep requests with 
** milisecond time resolution, then the time will be rounded up to 
** the nearest second. The number of miliseconds of sleep actually 
** requested from the operating system is returned.
*/
int sqlite3_sleep(int);

/*
** Return TRUE (non-zero) if the statement supplied as an argument needs
** to be recompiled.  A statement needs to be recompiled whenever the
** execution environment changes in a way that would alter the program
** that sqlite3_prepare() generates.  For example, if new functions or
** collating sequences are registered or if an authorizer function is
** added or changed.
**
*/
int sqlite3_expired(sqlite3_stmt*);

/*
** Move all bindings from the first prepared statement over to the second.
** This routine is useful, for example, if the first prepared statement
** fails with an SQLITE_SCHEMA error.  The same SQL can be prepared into
** the second prepared statement then all of the bindings transfered over
** to the second statement before the first statement is finalized.
*/
int sqlite3_transfer_bindings(sqlite3_stmt*, sqlite3_stmt*);

/*
** If the following global variable is made to point to a
** string which is the name of a directory, then all temporary files
** created by SQLite will be placed in that directory.  If this variable
** is NULL pointer, then SQLite does a search for an appropriate temporary
** file directory.
**
** Once sqlite3_open() has been called, changing this variable will invalidate
** the current temporary database, if any.
*/
extern char *sqlite3_temp_directory;

/*
** This function is called to recover from a malloc() failure that occured
** within the SQLite library. Normally, after a single malloc() fails the 
** library refuses to function (all major calls return SQLITE_NOMEM).
** This function restores the library state so that it can be used again.
**
** All existing statements (sqlite3_stmt pointers) must be finalized or
** reset before this call is made. Otherwise, SQLITE_BUSY is returned.
** If any in-memory databases are in use, either as a main or TEMP
** database, SQLITE_ERROR is returned. In either of these cases, the 
** library is not reset and remains unusable.
**
** This function is *not* threadsafe. Calling this from within a threaded
** application when threads other than the caller have used SQLite is
** dangerous and will almost certainly result in malfunctions.
**
** This functionality can be omitted from a build by defining the 
** SQLITE_OMIT_GLOBALRECOVER at compile time.
*/
int sqlite3_global_recover(void);

/*
** Test to see whether or not the database connection is in autocommit
** mode.  Return TRUE if it is and FALSE if not.  Autocommit mode is on
** by default.  Autocommit is disabled by a BEGIN statement and reenabled
** by the next COMMIT or ROLLBACK.
*/
int sqlite3_get_autocommit(sqlite3*);

/*
** Return the sqlite3* database handle to which the prepared statement given
** in the argument belongs.  This is the same database handle that was
** the first argument to the sqlite3_prepare() that was used to create
** the statement in the first place.
*/
sqlite3 *sqlite3_db_handle(sqlite3_stmt*);

/*
** Register a callback function with the database connection identified by the 
** first argument to be invoked whenever a row is updated, inserted or deleted.
** Any callback set by a previous call to this function for the same 
** database connection is overridden.
**
** The second argument is a pointer to the function to invoke when a 
** row is updated, inserted or deleted. The first argument to the callback is
** a copy of the third argument to sqlite3_update_hook. The second callback 
** argument is one of SQLITE_INSERT, SQLITE_DELETE or SQLITE_UPDATE, depending
** on the operation that caused the callback to be invoked. The third and 
** fourth arguments to the callback contain pointers to the database and 
** table name containing the affected row. The final callback parameter is 
** the rowid of the row. In the case of an update, this is the rowid after 
** the update takes place.
**
** The update hook is not invoked when internal system tables are
** modified (i.e. sqlite_master and sqlite_sequence).
**
** If another function was previously registered, its pArg value is returned.
** Otherwise NULL is returned.
*/
void *sqlite3_update_hook(
  sqlite3*, 
  void(*)(void *,int ,char const *,char const *,sqlite_int64),
  void*
);

/*
** Register a callback to be invoked whenever a transaction is rolled
** back. 
**
** The new callback function overrides any existing rollback-hook
** callback. If there was an existing callback, then it's pArg value 
** (the third argument to sqlite3_rollback_hook() when it was registered) 
** is returned. Otherwise, NULL is returned.
**
** For the purposes of this API, a transaction is said to have been 
** rolled back if an explicit "ROLLBACK" statement is executed, or
** an error or constraint causes an implicit rollback to occur. The 
** callback is not invoked if a transaction is automatically rolled
** back because the database connection is closed.
*/
void *sqlite3_rollback_hook(sqlite3*, void(*)(void *), void*);

/*
** This function is only available if the library is compiled without
** the SQLITE_OMIT_SHARED_CACHE macro defined. It is used to enable or
** disable (if the argument is true or false, respectively) the 
** "shared pager" feature.
*/
int sqlite3_enable_shared_cache(int);

/*
** Attempt to free N bytes of heap memory by deallocating non-essential
** memory allocations held by the database library (example: memory 
** used to cache database pages to improve performance).
**
** This function is not a part of standard builds.  It is only created
** if SQLite is compiled with the SQLITE_ENABLE_MEMORY_MANAGEMENT macro.
*/
int sqlite3_release_memory(int);

/*
** Place a "soft" limit on the amount of heap memory that may be allocated by
** SQLite within the current thread. If an internal allocation is requested 
** that would exceed the specified limit, sqlite3_release_memory() is invoked
** one or more times to free up some space before the allocation is made.
**
** The limit is called "soft", because if sqlite3_release_memory() cannot free
** sufficient memory to prevent the limit from being exceeded, the memory is
** allocated anyway and the current operation proceeds.
**
** This function is only available if the library was compiled with the 
** SQLITE_ENABLE_MEMORY_MANAGEMENT option set.
** memory-management has been enabled.
*/
void sqlite3_soft_heap_limit(int);

/*
** This routine makes sure that all thread-local storage has been
** deallocated for the current thread.
**
** This routine is not technically necessary.  All thread-local storage
** will be automatically deallocated once memory-management and
** shared-cache are disabled and the soft heap limit has been set
** to zero.  This routine is provided as a convenience for users who
** want to make absolutely sure they have not forgotten something
** prior to killing off a thread.
*/
void sqlite3_thread_cleanup(void);

/*
** Return meta information about a specific column of a specific database
** table accessible using the connection handle passed as the first function 
** argument.
**
** The column is identified by the second, third and fourth parameters to 
** this function. The second parameter is either the name of the database
** (i.e. "main", "temp" or an attached database) containing the specified
** table or NULL. If it is NULL, then all attached databases are searched
** for the table using the same algorithm as the database engine uses to 
** resolve unqualified table references.
**
** The third and fourth parameters to this function are the table and column 
** name of the desired column, respectively. Neither of these parameters 
** may be NULL.
**
** Meta information is returned by writing to the memory locations passed as
** the 5th and subsequent parameters to this function. Any of these 
** arguments may be NULL, in which case the corresponding element of meta 
** information is ommitted.
**
** Parameter     Output Type      Description
** -----------------------------------
**
**   5th         const char*      Data type
**   6th         const char*      Name of the default collation sequence 
**   7th         int              True if the column has a NOT NULL constraint
**   8th         int              True if the column is part of the PRIMARY KEY
**   9th         int              True if the column is AUTOINCREMENT
**
**
** The memory pointed to by the character pointers returned for the 
** declaration type and collation sequence is valid only until the next 
** call to any sqlite API function.
**
** If the specified table is actually a view, then an error is returned.
**
** If the specified column is "rowid", "oid" or "_rowid_" and an 
** INTEGER PRIMARY KEY column has been explicitly declared, then the output 
** parameters are set for the explicitly declared column. If there is no
** explicitly declared IPK column, then the output parameters are set as 
** follows:
**
**     data type: "INTEGER"
**     collation sequence: "BINARY"
**     not null: 0
**     primary key: 1
**     auto increment: 0
**
** This function may load one or more schemas from database files. If an
** error occurs during this process, or if the requested table or column
** cannot be found, an SQLITE error code is returned and an error message
** left in the database handle (to be retrieved using sqlite3_errmsg()).
**
** This API is only available if the library was compiled with the
** SQLITE_ENABLE_COLUMN_METADATA preprocessor symbol defined.
*/
int sqlite3_table_column_metadata(
  sqlite3 *db,                /* Connection handle */
  const char *zDbName,        /* Database name or NULL */
  const char *zTableName,     /* Table name */
  const char *zColumnName,    /* Column name */
  char const **pzDataType,    /* OUTPUT: Declared data type */
  char const **pzCollSeq,     /* OUTPUT: Collation sequence name */
  int *pNotNull,              /* OUTPUT: True if NOT NULL constraint exists */
  int *pPrimaryKey,           /* OUTPUT: True if column part of PK */
  int *pAutoinc               /* OUTPUT: True if colums is auto-increment */
);

/*
** Undo the hack that converts floating point types to integer for
** builds on processors without floating point support.
*/
#ifdef SQLITE_OMIT_FLOATING_POINT
# undef double
#endif

#ifdef __cplusplus
}  /* End of the 'extern "C"' block */
#endif
#endif
