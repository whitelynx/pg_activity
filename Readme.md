pg_activity
===========

A status-checking script for [PostgreSQL](http://www.postgresql.org/).


Prerequisites
-------------

- `psql` (from the `postgresql-client-common` package in Ubuntu)
- `head` and `realpath` (from the `coreutils` package in Ubuntu)
- `gawk` (from the `gawk` package in Ubuntu)
- `ip` (from the `iproute2` package in Ubuntu)


Installation
------------

```bash
git clone git@github.com:whitelynx/pg_activity.git
sudo ln -s $PWD/pg_activity/pg_activity /usr/local/bin/pg_activity
```


Usage
-----

To view usage information, pass `--help`:
```bash
pg_activity --help
```
