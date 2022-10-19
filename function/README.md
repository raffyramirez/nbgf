### Nob-Blocking Gap-Free (NBGF) Sequence function

This directory contains scripts to create the NBGF sequence standalone
stored function *next_seqno*. 

#### Latest NBGF stored function create scripts 

| File  | Description |
| ------------- | ------------- |
| [create_nbgf_function.sql](./create_nbgf_function.sql) | latest release |
| [create_nbgf_functionaio.sql](./create_nbgf_functionaio.sql) | all-in-one release |
| [create_nbgf_functionmain.sql](./create_nbgf_functionmain.sql) | main call release |

#### NBGF *next_seqno* stored function scripts

| File  | Description |
| ------------- | ------------- |
| [next_seqno_orderedopt.fun](./next_seqno_orderedopt.fun) | ordered optimized |
| [next_seqno_ordered.fun](./next_seqno_ordered.fun) | ordered unoptimized |
| [next_seqno_withparams.fun](./next_seqno_withparams.fun) | using parameters |
| [next_seqno_withconsts.fun](./next_seqno_withconsts.fun) | using constants |

#### non-NBGF *next_seqno* stored function scripts (example only)

| File  | Description |
| ------------- | ------------- |
| [non-nbgf_next_seqno_nowait.fun](./non-nbgf_next_seqno_nowait.fun) | update nowait |
| [non-nbgf_next_seqno.fun](./non-nbgf_next_seqno.fun) | direct update |

#### Shell scripts for generating latest versions (internal use only)

| File  | Description |
| ------------- | ------------- |
| [genfunctionaio.sh](./genfunctionaio.sh) | generate all-in-one |
| [genfunctionmain.sh](./genfunctionmain.sh) | generate main call|

