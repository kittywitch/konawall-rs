# konawall-rs

An automatic wallpaper fetching and setting script that supports i3 (but also anything that supports feh and xsetroot) and Sway that obtains wallpapers from konachan.

A module and package are available for NixOS+home-manager users in [arcnmx/nixexprs](https://github.com/arcnmx/nixexprs):

* [home-manager module](https://github.com/arcnmx/nixexprs/blob/master/modules/home/konawall.nix)
* [package](https://github.com/arcnmx/nixexprs/blob/master/pkgs/public/konawall.nix)

## Help

```
konawall 0.1.0
wallpaper randomizer that uses konachan

USAGE:
    konawall [OPTIONS] [tags]...

FLAGS:
    -h, --help       Prints help information
    -V, --version    Prints version information

OPTIONS:
        --common <common>     [default: score:>=200+width:>=1600+]
        --mode <mode>         [default: random]

ARGS:
    <tags>...     [default: nobody]
```

## Available Modes

* random - Picks one of the tag sets provided with --common prepended.
* map - Maps output to tag set directly with --common prepended.
* shuffle - Does what map does, but shuffles first.
