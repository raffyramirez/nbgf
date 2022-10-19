### Nob-Blocking Gap-Free (NBGF) Sequence tables

This directory contains scripts to create the NBGF sequence tables.

#### Latest NBGF sequence all table create scripts 

| File  | Description |
| ------------- | ------------- |
| [create_nbgf_tables.sql](./create_nbgf_tables.sql) | latest release |
| [create_nbgf_tablesaio.sql](./create_nbgf_tablesaio.sql) | all-in-one release |
| [create_nbgf_tablesmain.sql](./create_nbgf_tablesmain.sql) | main call release |

#### NBGF sequence table create scripts

| File  | Description |
| ------------- | ------------- |
| [nbgf_sequences.tab](./nbgf_sequences.tab) | sequence seqno |
| [nbgf_seqnos_cache.tab](./nbgf_seqnos_cache.tab) | seqnos cache |
| [nbgf_parameters.tab ](./nbgf_parameters.tab) | sequence parameters |
| [nbgf_returned_seqnos.tab](./nbgf_returned_seqnos.tab) | seqno returns |


#### NBGF sequence table constraints scripts

| File  | Description |
| ------------- | ------------- |
| [nbgf_sequences.cons](./nbgf_sequences.cons) | sequence seqno |
| [nbgf_seqnos_cache.cons](./nbgf_seqnos_cache.cons) | seqnos cache |
| [nbgf_parameters.cons](./nbgf_parameters.cons) | sequence parameters |
| [nbgf_returned_seqnos.cons](./nbgf_returned_seqnos.cons) | seqno returns |

#### NBGF sequence table references scripts

| File  | Description |
| ------------- | ------------- |
| [nbgf_seqnos_cache.refs](./nbgf_seqnos_cache.refs) | seqnos cache |
| [nbgf_parameters.refs](./nbgf_parameters.refs) | sequence parameters |
| [nbgf_returned_seqnos.refs](./nbgf_returned_seqnos.refs) | seqno returns |

#### NBGF sequence table index script

| File  | Description |
| ------------- | ------------- |
| [nbgf_seqnos_cache.idxs](./nbgf_seqnos_cache.idxs) | seqnos cache |

#### Shell scripts for generating latest versions (internal use only)

| File  | Description |
| ------------- | ------------- |
| [gentablesaio.sh](./gentablesaio.sh) | generate all-in-one |
| [gentablesmain.sh](./gentablesmain.sh) | generate main call |
