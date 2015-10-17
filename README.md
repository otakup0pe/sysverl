#sysVerl
----------------
This simple Erlang/OTP app represents the process control design pattern I have followed for years. I finally pulled it out of the various Erlang side projects I still maintain into something sharable. Thoughts/feedback welcome.

## Features

All the standard sysVinit service controls are present such as `start`, `stop`, `restart`, and `status`. Note that `start` will enable the Erlang VM heartbeat so you will actually need to use `stop` in order to properly stop the VM (or manually reset the heartbeat with `heart:set_cmd`). Note that `status` will simply return something that is roughly compatible with Nagios plugin based frameworks.

Erlang-specific service controls are `shell` and `rescue`. The latter will start your OTP app in the foreground and drop you to an Erlang shell. The former will connect to an existing instance of your already running app. The `hotload` command will, if [`magicbeam`](https://github.com/otakup0pe/magicbeam) is installed, will cause all configured OTP applications to reload.

## Assumptions

Off the top of my head there is only one key assumption in play and that is the location of the various OTP boot files. Other directory assumptions are calculated based on OTP release standards. The app version is automatically calculated and the app name is set during `rebar generate`.

* releases/APP_VSN/APP_NAME
* releases/start_clean

## Usage

You can include this package as a dependency with `rebar`. You will want to include an `overlay_vars` file in `reltool_config` with the following configuration items.

* `erlinit_component` is the name of your OTP app/release
* `erlinit_cookie` is the cookie to be used for authenticating node

You will then want to copy as templates the following files into your generated OTP release. The `.args` files will live under `config/` and the `erl_init.sh` script should be copied to `bin/` and named the same as `erlinit_component`.

* `sysverl/priv/syserl_init.sh`
* `sysverl/priv/vm.args`
* `sysverl/priv/vm-clean.args`

Unless your projects explicitly defines one, you should also copy `sysverl/priv/inetrc` into the `config/` directory of your generated OTP release.