rem --------------------------------------------------------------------------
rem NAME         : nbgf_sequences.tab
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence create table sql script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : none
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

CREATE TABLE nbgf_sequences (
  seqname VARCHAR2(30),
  seqno NUMBER DEFAULT 0
);

rem --------------------------------------------------------------------------
rem NAME         : nbgf_seqnos_cache.tab
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence create table script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : none
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

CREATE TABLE nbgf_seqnos_cache (
  seqname VARCHAR2(30),
  seqno NUMBER
);

rem --------------------------------------------------------------------------
rem NAME         : nbgf_parameters.tab
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence create table script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : none
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

CREATE TABLE nbgf_parameters (
  seqname VARCHAR2(30),
  cache_size NUMBER(2) DEFAULT 10, -- min 2 
  max_retry NUMBER(2) DEFAULT 5, -- >= 2 
  retry_wait NUMBER(2) DEFAULT 1, -- sleep seconds, >= 0 
  start_with NUMBER(6) DEFAULT 1, -- >= 1
  increment_by NUMBER(6) DEFAULT 1, -- >= 1
  max_value NUMBER(6), -- NULL for no limit
  disabled NUMBER(1) DEFAULT 0, -- 0=false, 1=true
  ordered NUMBER(1) DEFAULT 0 -- 0=false, 1=true
);

rem --------------------------------------------------------------------------
rem NAME         : nbgf_returned_seqnos.tab
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence create table script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : none
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

CREATE TABLE nbgf_returned_seqnos (
  seqname VARCHAR2(30),
  seqno NUMBER
);

rem --------------------------------------------------------------------------
rem NAME         : nbgf_sequences.cons
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence table constraints script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : nbgf_sequences.tab
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

ALTER TABLE nbgf_sequences
  MODIFY (seqname CONSTRAINT nbgf_sequences_nn1 NOT NULL ENABLE);
ALTER TABLE nbgf_sequences
  MODIFY (seqno CONSTRAINT nbgf_sequences_nn2 NOT NULL ENABLE);
ALTER TABLE nbgf_sequences
  ADD CONSTRAINT nbgf_sequences_pk
  PRIMARY KEY (seqname);
ALTER TABLE nbgf_sequences
  ADD CONSTRAINT nbgf_sequences_c1
  CHECK (seqname = UPPER(seqname));

rem --------------------------------------------------------------------------
rem NAME         : nbgf_seqnos_cache.cons
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence table constraints script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : nbgf_seqnos_cache.tab
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

ALTER TABLE nbgf_seqnos_cache
  MODIFY (seqname CONSTRAINT nbgf_seqnos_cache_nn1 NOT NULL ENABLE);
ALTER TABLE nbgf_seqnos_cache
  MODIFY (seqno CONSTRAINT nbgf_seqnos_cache_nn2 NOT NULL ENABLE);

rem --------------------------------------------------------------------------
rem NAME         : nbgf_parameters.cons
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence table constraints script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : nbgf_parameters.tab
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

ALTER TABLE nbgf_parameters
  MODIFY (seqname CONSTRAINT nbgf_parameters_nn1 NOT NULL ENABLE);
ALTER TABLE nbgf_parameters
  MODIFY (cache_size CONSTRAINT nbgf_parameters_nn2 NOT NULL ENABLE);
ALTER TABLE nbgf_parameters
  MODIFY (max_retry CONSTRAINT nbgf_parameters_nn3 NOT NULL ENABLE);
ALTER TABLE nbgf_parameters
  MODIFY (retry_wait CONSTRAINT nbgf_parameters_nn4 NOT NULL ENABLE);
ALTER TABLE nbgf_parameters
  MODIFY (start_with CONSTRAINT nbgf_parameters_nn5 NOT NULL ENABLE);
ALTER TABLE nbgf_parameters
  MODIFY (increment_by CONSTRAINT nbgf_parameters_nn6 NOT NULL ENABLE);
ALTER TABLE nbgf_parameters
  MODIFY (ordered CONSTRAINT nbgf_parameters_nn7 NOT NULL ENABLE);
ALTER TABLE nbgf_parameters
  MODIFY (disabled CONSTRAINT nbgf_parameters_nn8 NOT NULL ENABLE);
ALTER TABLE nbgf_parameters
  ADD CONSTRAINT nbgf_parameters_pk
  PRIMARY KEY (seqname)
  USING INDEX;
ALTER TABLE nbgf_parameters
  ADD CONSTRAINT nbgf_parameters_c1
  CHECK (cache_size >= 2);
ALTER TABLE nbgf_parameters
  ADD CONSTRAINT nbgf_parameters_c2
  CHECK (max_retry >= 2);
ALTER TABLE nbgf_parameters
  ADD CONSTRAINT nbgf_parameters_c3
  CHECK (retry_wait >= 0);
ALTER TABLE nbgf_parameters
  ADD CONSTRAINT nbgf_parameters_c4
  CHECK (ordered IN (0,1));
ALTER TABLE nbgf_parameters
  ADD CONSTRAINT nbgf_parameters_c5
  CHECK (disabled IN (0,1));

rem --------------------------------------------------------------------------
rem NAME         : nbgf_returned_seqnos.cons
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence table constraints script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : nbgf_returned_seqnos.tab
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

ALTER TABLE nbgf_returned_seqnos
  MODIFY (seqname CONSTRAINT nbgf_returned_seqnos_nn1 NOT NULL ENABLE);
ALTER TABLE nbgf_returned_seqnos
  MODIFY (seqno CONSTRAINT nbgf_returned_seqnos_nn2 NOT NULL ENABLE);
ALTER TABLE nbgf_returned_seqnos
  ADD CONSTRAINT nbgf_returned_seqnos_pk
  UNIQUE (seqname, seqno)
  USING INDEX;

rem --------------------------------------------------------------------------
rem NAME         : nbgf_seqnos_cache.refs
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence table references script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : nbgf_sequences.tab,.cons, nbgf_seqnos_cache.tab,.cons
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

ALTER TABLE nbgf_seqnos_cache
  ADD CONSTRAINT nbgf_seqnos_cache_f1
  FOREIGN KEY (seqname) REFERENCES nbgf_sequences
  ON DELETE CASCADE;

rem --------------------------------------------------------------------------
rem NAME         : nbgf_parameters.refs
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence table references script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : nbgf_sequences.tab,.cons, nbgf_parameters.tab,.cons
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

ALTER TABLE nbgf_parameters
  ADD CONSTRAINT nbgf_parameters_f1
  FOREIGN KEY (seqname) REFERENCES nbgf_sequences
  ON DELETE CASCADE;

rem --------------------------------------------------------------------------
rem NAME         : nbgf_returned_seqnos.refs
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence table references script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : nbgf_sequences.tab,.cons, nbgf_returned_seqnos.tab,.cons
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

ALTER TABLE nbgf_returned_seqnos
  ADD CONSTRAINT nbgf_returned_seqnos_f1
  FOREIGN KEY (seqname) REFERENCES nbgf_sequences
  ON DELETE CASCADE;

rem --------------------------------------------------------------------------
rem NAME         : nbgf_seqnos_cache.tab
rem AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
rem DESCRIPTION  : Non-Blocking Gap-Free sequence table indexes script
rem                see https://github.com/raffyramirez/nbgf
rem REQUIREMENTS : nbgf_seqnos_cache.tab,.cons
rem LICENSE      : MIT license - Free for personal and commercial use.
rem                You can change the code, but leave existing the headers,
rem                modification history and links intact.
rem HISTORY      : (author dev names: rramirez, rsramirez)
rem When         Who       What
rem ===========  ========  =================================================
rem 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
rem --------------------------------------------------------------------------

CREATE INDEX nbgf_seqnos_cache_i1
  ON nbgf_seqnos_cache
  (seqname);

