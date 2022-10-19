### Nob-Blocking Gap-Free (NBGF) Sequence tests

This directory contains scripts to test an NBGF sequence named *EMPNO*.

#### Setup NBGF sequence *EMPNO* direct or using package

| File  | Description |
| ------------- | ------------- |
| [createEMPNO.sql](./createEMPNO.sql) | direct create NBGF sequence EMPNO |
| [restartEMPNO.sql](./restartEMPNO.sql) | direct restart NBGF sequence EMPNO |
| [dropEMPNO.sql](./dropEMPNO.sql) | direct drop NBGF sequence EMPNO |
| [pkgcreateEMPNO.sql](./pkgcreateEMPNO.sql) | package create NBGF sequence EMPNO |
| [pkgrestartEMPNO.sql](./pkgrestartEMPNO.sql) | package restart NBGF sequence EMPNO |
| [pkgdropEMPNO.sql](./pkgdropEMPNO.sql) | package drop NBGF sequence EMPNO |

#### Generate NBGF sequence *EMPNO* seqnos via stored function *next_seqno*

| File  | Description |
| ------------- | ------------- |
| [nbgftest5-sqlcl.sql](./nbgftest5-sqlcl.sql) | get 5 EMPNO seqnos in sqlcl |
| [nbgftest5-sqlplus.sql](./nbgftest5-sqlplus.sql) | get 5 EMPNO seqnos in sqlplus |
| [orderednbgftest5.sql](./orderednbgftest5.sql) | get 5 ordered EMPNO seqnos |
| [nbgftest50-sqlcl.sql](./nbgftest50-sqlcl.sql) | get 50 EMPNO seqnos in sqlcl |
| [nbgftest50-sqlplus.sql](./nbgftest50-sqlplus.sql) | get 50 EMPNO seqnos in sqlplus |

#### Set NBGF sequence *EMPNO* ordered parameter

| File  | Description |
| ------------- | ------------- |
| [setnoorderEMPNO.sql](./setnoorderEMPNO.sql) | direct set NBGF sequence EMPNO ordered |
| [setorderedEMPNO.sql](./setorderedEMPNO.sql) | direct set NBGF sequence EMPNO unordered |
| [pkgsetnoorderEMPNO.sql](./pkgsetnoorderEMPNO.sql) | package set NBGF sequence EMPNO ordered |
| [pkgsetorderedEMPNO.sql](./pkgsetorderedEMPNO.sql) | package set NBGF sequence EMPNO unordered |

#### Generate NBGF sequence *EMPNO* seqnos via stored package *nbgf*

| File  | Description |
| ------------- | ------------- |
| [nbgfpkgtest5-sqlcl.sql](./nbgfpkgtest5-sqlcl.sql) | get 5 EMPNO seqnos in sqlcl |
| [nbgfpkgtest5-sqlplus.sql](./nbgfpkgtest5-sqlplus.sql) | get 5 EMPNO seqnos in sqlplus |
| [orderednbgfpkgtest5.sql](./orderednbgfpkgtest5.sql) | get 5 ordered EMPNO seqnos |

#### Restore NBGF sequence *EMPNO* seqno 1 via stored package *nbgf*

| File  | Description |
| ------------- | ------------- |
| [returnEMPNOseqno.sql](./returnEMPNOseqno.sql) | return EMPNO seqno 1 |
