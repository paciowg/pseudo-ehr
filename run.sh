#!/bin/bash
pg_ctl -D /opt/homebrew/var/postgres -l /opt/homebrew/var/postgres/server.log stop
pg_ctl -D /opt/homebrew/var/postgres -l /opt/homebrew/var/postgres/server.log start
rails s
