# NAME

Perlinstall - is installation script (modulino) that installs Perl using plenv. If you have sudo permissions it also installs git and "Development tools" for you. If you have git and development tools you can skip sudo.

# SYNOPSIS

    #if git installed (prompt for perl version and threads support)
    Perlinstall --mode=install_perl

    #full verbose with threads and no prompt
    ./Perlinstall.pm --mode=install_perl -v -v --perl=5.20.0 --threads=usethreads

    #sudo needed to install git, gcc and make
    ./Perlinstall.pm --mode=install_perl --sudo

    #install cperl 5.22.1 with nothreads
    ./Perlinstall.pm --mode=install_perl --cperl --perl=5.22.1 --threads=nothreads

# DESCRIPTION

    Perlinstall is installation script (built like modulino) that installs Perl using plenv. Prompts for perl version and to migrate Perl modules. If you have sudo permissions it will also install extra stuff like git, make and gcc.

    --mode=install_perl                installs latest Perl with perlenv and cpanm
    --verbose, -v                      enable verbose output (can be used twice)
    --sudo                             use sudo to install git and development tools (works only if you have sudo permissions)
    --perl=5.22.0, -p 5.22.0           pick perl to install (else prompts)
    --threads=nothreads, -t usethreads choose to install Perl with or without threads (else prompts)
    --cperl                            install cperl instead of normal Perl (use --perl to choose version, without threads only) 

    For help write:
    Perlinstall -h
    Perlinstall -m

# ACKNOWLEDGMENTS

The subs prompt() and \_is\_interactive() are borrowed from [IO::Prompt::Tiny](https://metacpan.org/pod/IO::Prompt::Tiny) (copied and not required because I couldn't afford non-core dependency). The are based on [ExtUtils::MakeMaker](https://metacpan.org/pod/ExtUtils::MakeMaker) and [IO::Interactive::Tiny](https://metacpan.org/pod/IO::Interactive::Tiny) (which is based on [IO::Interactive](https://metacpan.org/pod/IO::Interactive)). Thank you to the authors of those modules.

# LICENSE

Copyright (C) Martin Sebastijan Šestak.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Martin Sebastijan Šestak <msestak@irb.hr>

# EXAMPLE

    ./Perlinstall.pm --mode=install_perl
    Working without sudo (which is fine if you have git and essential build tools like gcc...).
    Great. You have git.
    Great. You have gcc. Continuing with plenv install.
    We have Perl 5.10.1 installed.
    plenv is not installed, installing now...
    plenv install success!
    Perl-Build is not installed, installing now...
    Perl-Build install success!
    export PATH success!
    plenv init success!
    sourcing .bash_profile success!
    We have sourced plenv 2.1.1-37-gb0945d5
    Choose which Perl version you want to install> [5.22.0] 
    Do you want to install Perl with {usethreads} or without threads {nothreads}?> [nothreads] 
    Installing 5.22.0 with nothreads.
    Perl 5.22.0 install success!
    plenv rehash success!
    Perl 5.22.0 set to global (plenv global) success!
    We switched from 5.10.1 to newly installed 5.22.0
    cpanm install success!
    plenv rehash success!
    To migrate modules from old Perl to new Perl run:
    plenv migrate-modules -n 5.10.1 5.22.0
    Restarting shell to see new Perl...
