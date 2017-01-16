# wp.sh

A shell utility to ease Wordpress website development workflow.

## Installation

0. Install wp-cli.phar somewhere
1. git clone `https://github.com/marcw/wp.sh` ~/wp.sh
2. chmod +x ~/wp.sh/wp.sh
3. ln -s ~/wp.sh/wp.sh /usr/local/bin/wp.sh

## Usage

At the root of your wordpress project, create a wp.sh.config file using this template

```
#!/bin/bash

host="my.hostname.com"
project_path="/path/to/project-files/on/the/server"
user="your-ssh-user"
local_hostname="//marc.weistroff.com.dev:8080"
remote_hostname="//marc.weistroff.net"
remote_wpcli="/remote/path/to/wp-cli.phar"
```

### Deployment (a.k.a. pushing local files to the remote server)

`wp.sh deploy [--force]`

### Sync (a.k.a. fetching remote files)

`wp.sh fetch [--force]`

### Deploy DB (a.k.a. pushing local database to the remote server)

`wp.sh deploy_db`

### Fetching DB (a.k.a. getting remote database)

`wp.sh fetch_db`

## Contributing

Yes, please!

## LICENSE

MIT. See `LICENSE` file.
