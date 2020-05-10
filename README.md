# Transfer Summary RI Client

Reference implementation client for the [PACIO Functional Status 
IG](https://paciowg.github.io/functional-status-ig) and [PACIO Cognitive Status IG](https://paciowg.github.io/cognitive-status-ig).

## Installation

To pull in remote `transfer-summary-ri-client` from github for local development:

```
cd ~/path/to/your/workspace/
git clone https://github.com/paciowg/transfer-summary-ri-client.git
```

## Running

Since this app is configured for heroku deployment, running it is slightly 
more effort than just `rails s`.

1. To start, you must be running `postgres`

    ```
    pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start
    ```
    (This gets old. Personally, I made a `pg_start` alias for this command)

2. Next, run the rails app the way you would any other

    ```
    cd ~/path/to/your/app/
    rails s
    ```

3. Now you should be able to see it up and running at `localhost:3000`

4. When done, gracefully stop your `puma` server

    ```
    Control-C
    ```

5. Finally, stop your `postgres` instance

    ```
    pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log stop
    ```
    (This also gets old. Personally, I made a `pg_stop` alias for this command)

## Copyright

Copyright 2019 The MITRE Corporation
