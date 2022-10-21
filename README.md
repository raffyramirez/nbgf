## Nob-Blocking Gap-Free (NBGF) Sequence

NBGF sequence is a user-defined manual sequence for a SQL relational database.
It uses a cache table to store generated sequence numbers. This cache is
replenished using 
[optimistic concurrency control](https://en.wikipedia.org/wiki/Optimistic_concurrency_control) (OCC)
with no retry. A sequence number is obtained from a cache table using 
[*FOR UPDATE SKIP LOCKi*](https://link.springer.com/chapter/10.1007/978-1-4302-1953-8_16) and
this "used" sequence number row is deleted from the cache. Because unique
rows are returned from the cache in a non-blocking manner, NBGF sequence is
scalable. Because of the delete from the cache, the returned NBGF sequence
is part of the calling program transaction and no skips or gaps in sequence numbers 
can occur. This repository contains the code to implement an NBGF sequence.

| Folder  | Description |
| ------------- | ------------- |
| [function](./function) | NBGF next seqno stored function script|
| [package](./package) | NBGF stored package scripts |
| [procedures](./procedures) | NBGF create and drop sequence stored procedure scripts |
| [tables](./tables) | create NBGF tables scripts |
| [tests](./tests) | NBGF sequence test scripts |
| [view](./view) | create NBGF sequence info view script |

### Use Cases

A sequence is a source of sequential numbers with a desired starting point,
increment and optionally, a maximum value. Its traditional use it so generate
unique identifier values but it can be used as a counter for units of 
items such as concert or lottery tickets, for slots or seats in a student course 
section in a registration system or for count of quantity sold or in stock for a product on sale. 

### NBGF sequence versus a database sequence

A database sequence does not guarantee there will be no skips or gaps in sequence 
numbers because it caches in memory two or more sequence numbers. Also, it is not 
transactional because any query can obtain a sequence number but not be part of
any committed transaction. Both of these may cause gaps or skips in sequence
numbers. However, database sequences are highly scalable since concurrent requests
never block and sequence number handling is done internally by the database engine.

NBGF is a transactional sequence which means the sequence number it returns is
part of a transaction and if that transaction does not *COMMIT*, then the sequence
number is returned to the cache. Due to the use of *SKIP LOCK* and OCC on the
replenish of the cache table, it is also scalable.

### NBGF sequence versus a simple counter column in a table

The old, traditional user-defined sequence uses a column of a table row to store the 
last sequence number or count. To get the next sequence number, the last column 
value is fetched and incremented for use by the calling program and this is used to 
update the column value so that the next caling program will in turn get a higher 
sequence number. 

While this all seems simple (and too good to be true), there are two flaws with 
this method that may not be apparent. The first is the lost update problem when 
two or more calling programs (each with their own database session)
concurrently try to increment the  column in succession but instead
one change overwrites the other rather than following a correct order. And second, there is blocking that occurs when one session 
accessing the same table row prevents another one to finish its update until it has
finished (i.e. does a *COMMIT* or *ROLLBACK*) in its transaction  - this may seem to
be a non-issue for stateless applications (e.g. web applications that have no
fixed, connected sessions to a database) but it does affect scalability because the lock contention causes one session to wait (and these waits can
cascade further with increased concurrency).

In the lost update problem, an earlier access increments and saves its sequence 
number which it *COMMIT*s but another access just before the earlier *COMMIT* likewise
gets its own sequence number and its *COMMIT* overwrites the earlier update. This is due
to read consistency in SQL which means no two sessions ever see uncommitted changes
and also reads never block writes. 

To prevent lost update requires optimistic concurrency control or OCC by using a
last update timestamp for the current sequence number value and checking if this
changed before updating. To prevent blocking of concurrent transactions (as with
stateful applications that have a long transaction or long living session with the
database), a pre-update lock reservation via SELECT FOR UPDATE NOWAIT allows 
upfront detection that an update is ongoing and blocking is avoded 
by allowing only one update at any time to succeed. In both these cases a retry 
loop is needed to handle failures. Still, only one session at a time succeeds to get
a sequence number and others are forced to wait in line until they succeed.

With a NBGF sequence, OCC is already included for replenish of the cache preventing any lost update. And for 
concurrency, it uses *FOR UPDATE SKIP LOCK* to return a cached sequence number that
allows multiple sessions to get their own sequence number without waiting  for others.
NBGF sequence therefore simplifies all that is needed compared to a simple counter
column and also includes features such as ordering of successive sequence numbers
for the same session, returning a used sequence number back to the cache and lastly,
helper functions for sequence maintanenace.

### Installing NBGF sequence objects

NBGF sequence was created using an Oracle database (since version 7) and requires
a schema with CREATE privilege for database tables and stored programs. It is
assumed below that the NBGF schema will be used purely for NBGF sequence only.

Using either sqlplus or sqlcl, first create the NBGF tables and view in the NBGF schema 
as follows.

```bash
SQL> start tables/create_nbgf_tables.sql
SQL> start view/create_nbgf_view.sql
```
Next, grant select on the *nbgf_sequence_info view* to allow information on any
NBGF sequence outside of the NBGF schema.

Then, create the single NBGF package (recommeded) to access all NBGF functions and 
procedures as follow.

```bash
SQL> start packages/create_nbgf_package.sql
```
After this, grant execute on the package *nbgf* to allow NBGF functions and 
procedures to be available for use outside of the NBGF schema. 

A new NBGF sequence is created using *nbgf.create_sequence*. The 
function *nbgf.next_seqno* returns an NBGF sequence number. More information on
the package stored programs are in the package directory.

If a package is not desired, the following will create similarly named standalone 
stored function and procedures instead of these packaged stored programs.
```bash
SQL> start functions/create_nbgf_function.sql
SQL> start procedures/create_nbgf_procedures.sql
```
A grant to execute each standalone stored program is needed to each one 
to be available for use outside the NBGF schema. Not all procedures or functionality
is provided in these standalone programs - for full functionality with the latest
fixes, use instead the NBGF package. 

### Test scripts

Go into the tests directory to test NBGF sequences. Refer to the directory README
for details.

Note that Oracle's *dbms_output* has an internal variable for it parameters
so NBGF sequence numbers are accepted as part of a transacton. Queries cannot
ne used to get NBGF sequence numbers since it generates a transaction. 

### License

All NBGF sequence code is provided under the MIT license. 

### Limitations

As with traditional counter column sequence number generation, NBGF sequences
are transactional which means they are part of or start a SQL transacion.
Hence, unlike database sequences where you can get a sequence number using
a query, NBGF sequence number needs to be stored in a calling program
variable.

This transactional
nature of either counter column or NBGF sequence is what makes it
gap or skip free since the transaction related to the generated sequence number is "used" only when the calling
program transacion ends with a *COMMIT*. What make NBGF different is that
it uses *FOR UPDATE SKIP LOCK* to get a sequence number cache table row for 
a sequence number which is non-blocking across multiple calling programs.

Currently, only increasing NBGF sequence (e.g. positive *increment_by*) is implemented. Cyclic sequence (e.g. restart after *max_value* reached) is also not implemented. 

The Oracle NUMBER data type without limits in precision or scale is used to
make sequence numbers generic and because NBGF was originally created and
implemented in older Oracle versions. This is easy to change to *INTEGER* of
fixed precision type to increase efficiency. 

Only Oracle database 18c and above is supported in the current repository code.

### Updates and code description

Go into the object direcctories listed above to see more details about each NBGF object
or stored program. Updates will be loaded into the appropriate directory in the future.

Addition of decreasing and cyclic sequence is being investigated.
Since *SELECT FOR UPDATE NOWAIT* and *FOR UPDATE SKIP LOCKED* available in
Mysql and Postgres, porting to those platforms are also being investigated.

However, neither Mysql nor Postgres implement *AUTONOMOUS TRANSACTION*
that is used to isolate NBGF cache replenish from the calling transaction.
A workaround in Postgres is to use an external server-side session for 
*AUTONOMOUS TRANSACTION* SQL but this is done outside of the database engine
and is dependent on database server operating system process mechanisms
that has securiy implications.

For the latest updates and more detailed code description, see the blog posts 
regarding NBGF sequence in https://rsramirez.blogspot.com.
