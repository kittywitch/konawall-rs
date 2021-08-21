# konawall-rs

An automatic wallpaper fetching and setting script that supports i3 and Sway that obtains wallpapers from konachan.

```
konawall 0.1.0
wallpaper randomizer that uses konachan

USAGE:
    konawall [OPTIONS] --wm <wm> [tags]...

FLAGS:
    -h, --help       Prints help information
    -V, --version    Prints version information

OPTIONS:
        --common <common>     [default: score:>=200+width:>=1600+]
        --mode <mode>         [default: random]
        --wm <wm>

ARGS:
```

## Available Modes

* random - Picks one of the tag sets provided with --common prepended.
* map - Maps output to tag set directly with --common prepended.
* shuffle - Does what map does, but shuffles first.
