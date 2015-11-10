# NAME

Perlinstall - is installation script (modulino) that installs Perl (or cperl) using plenv. It also installs cpanm with Perl you are installing. If you have sudo permissions it also installs git and your Linux distribution based "Development tools" for you. If you have git, gcc and make you can skip sudo.

# SYNOPSIS

    #first install in clean environment
    #sudo needed to install git, gcc and make
    Perlinstall.pm --mode=install_perl --perl=5.12.1 -t nothreads --sudo

    #if git installed (prompt for perl version and threads support)
    Perlinstall --mode=install_perl

    #full verbose with threads and no prompt
    Perlinstall.pm --mode=install_perl -v -v --perl=5.20.0 --threads=usethreads

    #install cperl 5.22.1 with nothreads
    ./Perlinstall.pm --mode=install_perl --cperl --perl=5.22.1

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

    ./Perlinstall.pm --mode=install_perl --perl=5.14.1 -t nothreads
    RUNNING ACTION for mode: install_perl
    Working without sudo, which is fine if you have git and essential build tools like gcc and make...).
    Great. You have git.
    Great. You have gcc.
    Great. You have make. Continuing with plenv install.
    We have Perl 5.12.1 installed.
    We have plenv 2.1.1-37-gb0945d5
    Perl-Build is installed.
    /home/msestak/.bash_profile is already set for plenv.
    Installed Perl-5.14.1
    plenv rehash success!
    Perl 5.14.1 set to global (through plenv global) success!
    Perl 5.14.1 set to global (ENV manipulation).
    We have Perl 5.14.1 installed.
    We switched from 5.12.1 to newly installed 5.14.1
    cpanm installed through plenv.
    plenv rehash success!
    To migrate modules from old Perl to new Perl run:
    plenv migrate-modules -n 5.12.1 5.14.1
    TIME when finished: 180 sec
    Restarting shell to see new Perl...
    
