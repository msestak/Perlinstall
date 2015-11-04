# NAME

Perlinstall - is installation script (modulino) that installs Perl using plenv. If you have sudo permissions it also installs git and "Development tools" for you.

# SYNOPSIS
 #if git installed
 Perlinstall --mode=install\_perl

    #full verbose with git installed
    ./Perlinstall.pm --mode=install_perl -v -v

    #sudo needed to also install git
    ./Perlinstall.pm --mode=install_perl --sudo

# DESCRIPTION

    Perlinstall is installation script (built like modulino) that installs Perl using plenv. Asks for perl version and to migrate Perl modules. If you have sudo permissions it will also install extra stuff like git, make and gcc.

    --mode=install_perl            installs latest Perl with perlenv and cpanm
    --verbose, -v                          enable verbose output (can be used twice)
    --sudo                                         use sudo to install git and development tools (only if you have sudo permissions)

    For help write:
    Perlinstall -h
    Perlinstall -m

# LICENSE

Copyright (C) Martin Sebastijan Šestak.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Martin Sebastijan Šestak <msestak@irb.hr>

# EXAMPLE
