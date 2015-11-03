# NAME

Perlinstall - is installation script that installs Perl using plenv. If you have sudo permissions it also installs git and "Development tools" for you.

# SYNOPSIS

    Perlinstall --mode=install_perl

    #full log
    ./Perlinstall.pm --mode=install_perl -v -v --sudo

# DESCRIPTION

    Perlinstall is installation script that installs Perl using plenv (automatic install). If you have sudo permissions you can alos install extra stuff like git.

    --mode=install_perl            installs latest Perl with perlenv and cpanm
    --verbose, -v                          enable verbose output (can be used twice) 

    For help write:
    Perlinstall -h
    Perlinstall -m

# LICENSE

Copyright (C) Martin Sebastijan Šestak.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

mocnii <msestak@irb.hr>

# EXAMPLE
