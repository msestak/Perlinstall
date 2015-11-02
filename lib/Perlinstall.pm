#!/usr/bin/env perl
package Perlinstall;

use 5.008001;
use strict;
use warnings;
use File::Spec::Functions qw(:ALL);
use Carp;
use Getopt::Long;
use Pod::Usage;
use IPC::Open3;
use Data::Dumper;
use Exporter qw/import/;

our $VERSION = "0.001";

our @EXPORT_OK = qw{
  run

};

#MODULINO - works with debugger too
run() if !caller() or (caller)[0] eq 'DB';

### INTERFACE SUB starting all others ###
# Usage      : main();
# Purpose    : it starts all other subs and entire modulino
# Returns    : nothing
# Parameters : none (argument handling by Getopt::Long)
# Throws     : lots of exceptions from logging
# Comments   : start of entire module
# See Also   : n/a
sub run {
    croak 'main() does not need parameters' unless @_ == 0;

    #first capture parameters to enable verbose flag for logging
    my ($param_href) = get_parameters_from_cmd();

    #preparation of parameters
    my $verbose    = $param_href->{verbose};
    my $quiet      = $param_href->{quiet};
    my $sudo      = $param_href->{sudo};
    my @mode     = @{ $param_href->{mode} };
	my $URL      = $param_href->{url};
	my $OPT      = $param_href->{opt};
    my $SANDBOX = $param_href->{sandbox};
    my $INFILE   = $param_href->{infile};
    my $OUT      = $param_href->{out};   #not used
    my $HOST     = $param_href->{host};
    my $DATABASE = $param_href->{database};   #not used
    my $USER     = $param_href->{user};
    my $PASSWORD = $param_href->{password};
    my $PORT     = $param_href->{port};
    my $SOCKET   = $param_href->{socket};

    #get dump of param_href if -v (verbose) flag is on (for debugging)
    print '$param_href = ', Dumper($param_href) if $verbose;

    #call write modes (different subs that print different jobs)
	my %dispatch = (
        install_perl             => \&install_perl,                  #using perlenv

    );

    foreach my $mode (@mode) {
        if ( exists $dispatch{$mode} ) {
            warn "RUNNING ACTION for mode: $mode";

            $dispatch{$mode}->( $param_href );

            warn "TIME when finished for: $mode";
        }
        else {
            #complain if mode misspelled or just plain wrong
            die "Unrecognized mode --mode={$mode} on command line thus aborting";
        }
    }

    return;
}

### INTERNAL UTILITY ###
# Usage      : my ($param_href) = get_parameters_from_cmd();
# Purpose    : processes parameters from command line
# Returns    : $param_href --> hash ref of all command line arguments and files
# Parameters : none -> works by argument handling by Getopt::Long
# Throws     : lots of exceptions from die
# Comments   : it starts logger at start
# See Also   : init_logging()
sub get_parameters_from_cmd {

	#cli part
	my @arg_copy = @ARGV;
	my (%cli, @mode);
	$cli{quiet}   = 0;
	$cli{verbose} = 0;
	$cli{sudo}    = 0;

	#mode, quiet and verbose can only be set on command line
    GetOptions(
        'help|h'        => \$cli{help},
        'man|m'         => \$cli{man},
        'url=s'         => \$cli{url},
        'sandbox|sand=s'=> \$cli{sandbox},
        'opt=s'         => \$cli{opt},

        'infile|if=s'   => \$cli{infile},
        'out|o=s'       => \$cli{out},
        'host|h=s'      => \$cli{host},
        'database|d=s'  => \$cli{database},
        'user|u=s'      => \$cli{user},
        'password|p=s'  => \$cli{password},
        'port|po=i'     => \$cli{port},
        'socket|s=s'    => \$cli{socket},
        'mode|mo=s{1,}' => \$cli{mode},       #accepts 1 or more arguments
        'quiet|q'       => \$cli{quiet},      #flag
        'verbose+'      => \$cli{verbose},    #flag
        'sudo'          => \$cli{sudo},       #flag
    ) or pod2usage( -verbose => 1 );

	#you can specify multiple modes at the same time
	@mode = split( /,/, $cli{mode} );
	$cli{mode} = \@mode;
	die 'No mode specified on command line' unless $cli{mode};
	
	pod2usage( -verbose => 1 ) if $cli{help};
	pod2usage( -verbose => 2 ) if $cli{man};
	
	#if not -q or --quit print all this (else be quiet)
	if ($cli{quiet} == 0) {
		#print STDERR 'My @ARGV: {', join( "} {", @arg_copy ), '}', "\n";
	
		if ($cli{infile}) {
			print 'My input file: ', canonpath($cli{infile}), "\n";
			$cli{infile} = rel2abs($cli{infile});
			$cli{infile} = canonpath($cli{infile});
			print "My absolute input file: $cli{infile}\n";
		}
		if ($cli{out}) {
			print 'My output path: ', canonpath($cli{out}), "\n";
			$cli{out} = rel2abs($cli{out});
			$cli{out} = canonpath($cli{out});
			print "My absolute output path: $cli{out}\n";
		}
	}
	else {
		$cli{verbose} = -1;   #and logging is OFF
	}
	
    return ( \%cli );
}


### INTERNAL UTILITY ###
# Usage      : my ($stdout, $stderr, $exit) = capture_output( $cmd, $param_href );
# Purpose    : accepts command, executes it, captures output and returns it in vars
# Returns    : STDOUT, STDERR and EXIT as vars
# Parameters : ($cmd_to_execute)
# Throws     : 
# Comments   : second param is verbose flag (default off)
# See Also   :
sub capture_output {
    croak( 'capture_output() needs a $cmd' ) unless (@_ ==  2 or 1);
    my ($cmd, $param_href) = @_;

    my $verbose = defined $param_href->{verbose}  ? $param_href->{verbose}  : undef;   #default is silent
    print "Report: COMMAND is: $cmd\n" if $verbose;

	no warnings 'once';
	my $pid = open3(\*WRITER, \*READER, \*ERROR, $cmd);
	#if \*ERROR is 0, stderr goes to stdout

	my $stdout = do { local $/; <READER> };
	my $stderr = do { local $/; <ERROR> };
	$stdout = '' if !defined $stdout;
	$stderr = '' if !defined $stderr;

	waitpid( $pid, 0 ) or die "$!\n";
	my $exit =  $? >> 8;

    if ($verbose == 2) {
        print 'STDOUT is: ', "$stdout", "\n", 'STDERR  is: ', "$stderr", "\n", 'EXIT   is: ', "$exit\n";
    }

    return  $stdout, $stderr, $exit;
}


### INTERNAL UTILITY ###
# Usage      : exec_cmd($cmd_git, $param_href);
# Purpose    : accepts command, executes it and checks for success
# Returns    : prints info
# Parameters : ($cmd_to_execute, $param_href)
# Throws     : 
# Comments   : second param is verbose flag (default off)
# See Also   :
sub exec_cmd {
	croak( 'exec_cmd() needs a $cmd' ) unless (@_ == 2 or 3);
    my ($cmd, $param_href, $cmd_info) = @_;
	if (!defined $cmd_info) {
		($cmd_info)  = $cmd =~ m/\A(\w+)/;
	}

    my ($stdout, $stderr, $exit) = capture_output( $cmd, $param_href );
    if ($exit == 0 ) {
        print "$cmd_info success!\n";
    }
	else {
        print "$cmd_info failed!\n";
	}
}


### INTERFACE SUB ###
# Usage      : install_perl( $param_href );
# Purpose    : install latest perl if not installed
# Returns    : nothing
# Parameters : ( $param_href ) params from command line
# Throws     : croaks if wrong number of parameters
# Comments   : first sub in chain, run only once at start
# See Also   :
sub install_perl {
    croak ('install_perl() needs a $param_href' ) unless @_ == 1;
    my ( $param_href ) = @_;
    my $sudo    = $param_href->{sudo};
    my $verbose = $param_href->{verbose};
	my $shell = $ENV{SHELL};   #to be used in commands

	if ($sudo) {
		print "Working with sudo permissions!!!\n";
	}
	else {
		print "Working without sudo:(\n";
	}

	#install prerequisites for plenv
	my $installer = do {
		if    (-e '/etc/debian_version') { 'apt-get' }
		elsif (-e '/etc/centos-release') { 'yum' }
		elsif (-e '/etc/redhat-release') { 'yum' }
		else                             { 'yum' }
	};

	#print "$installer\n";

	#install git, Development tools
    my $cmd_check_git = 'git --version';
    my ($stdout_check_git, $stderr_check_git, $exit_check_git) = capture_output( $cmd_check_git, $param_href );
	if ($exit_check_git == 0) {
		print "Great. You have git. Continuing with plenv install.\n";
	}
	else {
		#we are on CentOS or Redhat linux and have sudo
		if ( ($sudo == 1) and ($installer eq 'yum') ) {
			my $cmd_git = "sudo $installer -y install git";
			exec_cmd($cmd_git, $param_href, 'git install');

			my $cmd_tools = q{sudo yum -y groupinstall "Development tools"};
			exec_cmd($cmd_tools, $param_href, 'Development tools install');
		}
		elsif ( ($sudo == 1) and ($installer eq 'apt-get') ) {
			my $cmd_git = "sudo $installer -y install git";
			exec_cmd($cmd_git, $param_href, 'git install');

			my $cmd_tools = q{sudo apt-get install build-essential};
			exec_cmd($cmd_tools, $param_href, 'build-essential tools install');
		}
		else {
			die "git missing. You should first install git or try again with --sudo option if you have sudo permissions :)";
		}
	}

    #check perl version
    my $cmd_perl_ver = 'perl -v';
    my ($stdout_perl_ver, $stderr_perl_ver, $exit_perl_ver) = capture_output( $cmd_perl_ver, $param_href );
    if ($exit_perl_ver == 0) {
        if ( $stdout_perl_ver =~ m{v(\d+\.(\d+)\.\d+)}g ) {
            my $perl_ver = $1;
            my $ver_num = $2;
            print "We have Perl $perl_ver\n";
		}
		else {
			print "Couldn't find Perl version\n";
		}
	}
	else {
		print "Strange. Perl is not installed. No problem we will fix that in a moment\n";
	}

	#check if plenv installed
	my $plenv_flag = 0;
    my $cmd_plenv_ver = 'plenv --version';
    my ($stdout_plenv_ver, $stderr_plenv_ver, $exit_plenv_ver) = capture_output( $cmd_plenv_ver, $param_href );
    if ($exit_plenv_ver == 0) {
        print "We have $stdout_plenv_ver\n";
		$plenv_flag = 1;
	}
	else {
		print "plenv is not installed.\n";
	}

    #start perlenv install
	if ($plenv_flag == 0) {
	    my $cmd_plenv = 'git clone git://github.com/tokuhirom/plenv.git ~/.plenv';
		exec_cmd($cmd_plenv, $param_href, 'plenv install');
		$plenv_flag = 1;
	}

	#check if Perl-Build plugin for plenv installed
	my $perl_build_flag = 0;
	my $perl_build_dir = catdir("$ENV{HOME}", '/.plenv/plugins/perl-build');
	print "$perl_build_dir\n";
	if (-d $perl_build_dir and -s $perl_build_dir) {
		$perl_build_flag = 1;
		print "Perl-Build is installed\n";
	}
	else {
		print "Perl-Build is not installed\n";
	}

	#installing Perl-Build plugin for install function in plenv
	if ( ($plenv_flag == 1) and ($perl_build_flag == 0) ) {
		my $cmd_perl_build = q{git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/};
		exec_cmd($cmd_perl_build, $param_href, 'Perl-Build install');
	}

	
	#checking if plenv settings in place
	my $bash_profile;
	if ($installer eq 'yum') {   #on CentOS
		$bash_profile = catfile("$ENV{HOME}", '.bash_profile');
	}
	else {   #on Ubuntu
		$bash_profile = catfile("$ENV{HOME}", '.profile');
	}

	open my $fh, "<", $bash_profile or die "can't open $bash_profile:$!";
	my $prof = do {local$/; <$fh>};
	(my $plenv_match) = $prof =~ m/plenv/;
    
	#updating .bash_profile for plenv to work
	my $plenv_source_flag = 0;
	if (!defined $plenv_match) {
		my ($cmd_path, $cmd_eval, $cmd_exec);
		if ($installer eq 'yum') {   #on CentOS
			$cmd_path = q{echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> ~/.bash_profile};
			$cmd_eval = q{echo 'eval "$(plenv init -)"' >> ~/.bash_profile};
			$cmd_exec = q{source $HOME/.bash_profile};
			#$cmd_exec = q{exec $SHELL -l};
		}
		else {   #on Ubuntu
			$cmd_path = q{echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> ~/.profile};
			$cmd_eval = q{echo 'eval "$(plenv init -)"' >> ~/.profile};
			$cmd_exec = q{source $HOME/.profile};
			#$cmd_exec = q{exec $SHELL -l};
		}

    	exec_cmd ($cmd_path, $param_href, 'export PATH');
    	exec_cmd ($cmd_eval, $param_href, 'plenv init');
		sleep 1;
    	exec_cmd ($cmd_exec, $param_href, 'sourcing .bash_profile');

		#PLENV_SHELL=bash
		#[msestak@vcl-1-119 ~]$ echo $PATH
		#/home/msestak/.plenv/shims:/home/msestak/.plenv/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/home/msestak/bin:/home/msestak/bin
		my $pid = fork;
		if (!defined $pid) {
			die "couldn't fork!";
		}
		if ($pid == 0) {
			#child
			#checking if sourcing plenv worked
			my $cmd_plenv_ver2 = q{$SHELL -lc "plenv --version"};
			my ($stdout_plenv_ver2, $stderr_plenv_ver2, $exit_plenv_ver2) = capture_output( $cmd_plenv_ver2, $param_href );
			if ($exit_plenv_ver2 == 0) {
				print "We have sourced $stdout_plenv_ver2\n";
				$plenv_source_flag = 1;

				#print 'executing exec $SHELL -l', "\n";
				#exec "\$SHELL -l" or print STDERR "couldn't exec foo: $!\n";

				exit 0;
			}
			else {
				die "Sourcing plenv didn't work.\n";
			}
		}
		else {
			#parent
			print "in parent $$, waiting for child:$pid\n";
			waitpid($pid, 0);
		}
	}
	else {
		print "$bash_profile already set for plenv\n";
	}

	#install Perl in a fork (to use restarted shell)
	my $pid2 = fork;
	if (!defined $pid2) {
		die "couldn't fork!";
	}
	if ($pid2 == 0) {
		#child
	    #list all perls available (on verbose only)
		if ($plenv_flag == 1 or $plenv_source_flag == 1) {
			my $cmd_list_perls = q{$SHELL -lc "plenv install --list"};
			my ($stdout_list, $stderr_list, $exit_list) = capture_output( $cmd_list_perls, $param_href );
			if ($verbose == 1) {
				print "$stdout_list\n";
			}
		}
	    
	    #ask to choose which Perl to install
		my $perl_install_flag = 0;
		if ($plenv_flag == 1 or $plenv_source_flag == 1) {
			my $perl_to_install = prompt ('Choose which Perl version you want to install>', '5.22.0');
			my $thread_options = 'usethreads nothreads';
			print "Thread options are: $thread_options\n";
			my $thread_option = prompt ('Do you want to install Perl with or without threads?>', 'nothreads');
			print "Installing $perl_to_install with $thread_option\n";
	
			#install Perl
			my $cmd_install;
			if ($thread_option eq 'nothreads') {
				$cmd_install = qq{plenv install -j 8 -Dcc=gcc $perl_to_install};
			}
			else {
				$cmd_install = qq{plenv install -j 8 -Dcc=gcc -D usethreads $perl_to_install};
			}
			exec_cmd ($cmd_install, $param_href, "Perl $perl_to_install install");
		
			#finish installation, set perl as global
			my $cmd_rehash = q{plenv rehash};
			my $cmd_global = qq{plenv global $perl_to_install};
			exec_cmd ($cmd_rehash, $param_href, "plenv rehash");
			exec_cmd ($cmd_global, $param_href, "Perl $perl_to_install set to global");
	
			$perl_install_flag = 1;
		}
	
		#check if right Perl installed
		if ($perl_install_flag == 1) {
			my ($stdout_ver2, $stderr_ver2, $exit_ver2) = capture_output( $cmd_perl_ver, $param_href );
			if ($exit_ver2 == 0) {
				if ( $stdout_ver2 =~ m{v(\d+\.(\d+)\.\d+)}g ) {
					my $perl_ver2 = $1;
					print "We have Perl $perl_ver2\n";
				}
			}
		}
	
		#install cpanm to installed perl
		if ($perl_install_flag == 1) {
			my $cmd_cpanm = q{plenv install-cpanm};
			exec_cmd ($cmd_cpanm, $param_href, "cpanm install");
			if ($sudo == 1) {
				my $cmd_lib   = q{sudo cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)};
				exec_cmd ($cmd_lib, $param_href, "local lib setup");
				
			}
			else {
				print "Please setup you local lib with sudo permissions:\nsudo cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)\n";
			}
		}

		#end of child
		exit 0;
	}
	else {
		#parent
		print "in parent $$, waiting for child:$pid2\n";
		waitpid($pid2, 0);
	}

	#restarting shell to see new perl
	print "Restarting shell ...\n";
	my $cmd_shell = exec "source $bash_profile";

    return;
}



sub install_perl2 {
    croak ('install_perl() needs a $param_href' ) unless @_ == 1;
    my ( $param_href ) = @_;

    #check perl version
    my $cmd_perl_version = 'perl -v';
    my ($stdout, $stderr, $exit) = capture_output( $cmd_perl_version, $param_href );
    if ($exit == 0) {
        if ( $stdout =~ m{v(\d+\.(\d+)\.\d+)}g ) {
            my $perl_ver = $1;
            my $ver_num = $2;
            print "We have Perl $perl_ver\n";

            #start perlenv install
            print "Checking if we can install plenv\n";
            my $cmd_plenv = 'git clone git://github.com/tokuhirom/plenv.git ~/.plenv';
            my ($stdout_env, $stderr_env, $exit_env) = capture_output( $cmd_plenv, $param_href );
            my ($git_missing) = $stderr_env =~ m{(git)};
            my ($plenv_exist) = $stderr_env =~ m{(plenv)};

            if ($exit_env != 0 ) {
                if ( $git_missing ) {
                    warn( 'Need to install git' );
                    my $cmd_git = 'sudo yum -y install git';
					exec_cmd($cmd_git, $param_href, 'git install');

					#if git is missing other tools are missing too
                    my $cmd_tools = q{sudo yum -y groupinstall "Development tools"};
					exec_cmd($cmd_tools, $param_href, 'Development tools install');

					#install plenv
					exec_cmd($cmd_plenv, $param_href, 'plenv install');

					#installing Perl-Build plugin for install function in plenv
					my $cmd_perl_build = q{git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/};
					exec_cmd ($cmd_perl_build, $param_href, 'Perl-Build install');
				}

				elsif ( $plenv_exist ) {
					warn( "plenv already installed: $stderr_env" );

					#installing Perl-Build plugin for install function in plenv
					my $cmd_perl_build = q{git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/};
					exec_cmd ($cmd_perl_build, $param_href, 'Perl-Build install');
				}
            }

            else {
                print "Installed plenv\n";
				my $bash_profile = "$ENV{HOME}/.bash_profile";
				open my $fh, "<", $bash_profile or die "can't open $bash_profile:$!";
				my $prof = do {local$/; <$fh>};
				(my $plenv_match) = $prof =~ m/plenv/;
                
				if (!defined $plenv_match) {
					#updating .bash_profile for plenv to work
                	my $cmd_path = q{echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> ~/.bash_profile};
                	my $cmd_eval = q{echo 'eval "$(plenv init -)"' >> ~/.bash_profile};
                	my $cmd_exec = q{source $HOME/.bash_profile};
                	exec_cmd ($cmd_path, $param_href, 'export PATH');
                	exec_cmd ($cmd_eval, $param_href, 'plenv init');
                	exec_cmd ($cmd_exec, $param_href, 'sourcing .bash_profile');
                	print "Updated \$PATH variable and initiliazed plenv\n";

					#install cpanm globally
					my $cmd_cpanm = q{plenv install-cpanm};
					#my $cmd_lib   = q{sudo cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)};
					exec_cmd ($cmd_cpanm, $param_href, "cpanm install");

				}
				else {
					warn "$bash_profile already set for plenv";
				}
                
                #installing Perl-Build plugin for install function in plenv
				my $cmd_perl_build = q{git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/};
                exec_cmd ($cmd_perl_build, $param_href, 'Perl-Build install');
			}

            #list all perls available
            my $cmd_list_perls = q{plenv install --list};
            my ($stdout_list, $stderr_list, $exit_list) = capture_output( $cmd_list_perls, $param_href );
			#print "$stdout_list\n";
            
            #ask to choose which Perl to install
            my $perl_to_install = prompt ('Choose which Perl version you want to install>', '5.22.0');
            my $thread_options = 'usethreads nothreads';
			print "$thread_options\n";
            my $thread_option = prompt ('Do you want to install Perl with or without threads?>', 'nothreads');
            print "Installing $perl_to_install with $thread_option\n";

            #install Perl
            my $cmd_install;
            if ($thread_option eq 'nothreads') {
                $cmd_install = qq{plenv install -j 8 -Dcc=gcc $perl_to_install};
            }
            else {
                $cmd_install = qq{plenv install -j 8 -Dcc=gcc -D usethreads $perl_to_install};
            }
            exec_cmd ($cmd_install, $param_href, "Perl $perl_to_install install");

            #finish installation, set perl as global
            my $cmd_rehash = q{plenv rehash};
            my $cmd_global = qq{plenv global $perl_to_install};
            exec_cmd ($cmd_rehash, $param_href, "plenv rehash");
            exec_cmd ($cmd_global, $param_href, "Perl set to global");

           #check if right Perl installed
           my ($stdout_ver, $stderr_ver, $exit_ver) = capture_output( $cmd_perl_version, $param_href );
           if ($exit_ver == 0) {
                if ( $stdout_ver =~ m{v(\d+\.(\d+)\.\d+)}g ) {
                    my $perl_ver2 = $1;
                    print "We have Perl $perl_ver2\n";
                }
            }
        }
    }
    else {
        carp( 'Got lost checking Perl version' );
    }

    return;
}

# Copied from ExtUtils::MakeMaker (by many authors)
sub prompt {
    my ( $mess, $def ) = @_;
    Carp::croak("prompt function called without an argument")
      unless defined $mess;

    my $dispdef = defined $def ? "[$def] " : " ";
    $def = defined $def ? $def : "";

    local $| = 1;
    local $\;
    print "$mess $dispdef";

    my $ans;
    if ( $ENV{PERL_MM_USE_DEFAULT} || !_is_interactive() ) {
        print "$def\n";
    }
    else {
        $ans = <STDIN>;
        if ( defined $ans ) {
            chomp $ans;
        }
        else { # user hit ctrl-D
            print "\n";
        }
    }

    return ( !defined $ans || $ans eq '' ) ? $def : $ans;
}

# Copied (without comments) from IO::Interactive::Tiny by Daniel Muey,
# based on IO::Interactive by Damian Conway and brian d foy
sub _is_interactive {
    my ($out_handle) = ( @_, select );
    return 0 if not -t $out_handle;
    if ( tied(*ARGV) or defined( fileno(ARGV) ) ) {
        return -t *STDIN if defined $ARGV && $ARGV eq '-';
        return @ARGV > 0 && $ARGV[0] eq '-' && -t *STDIN if eof *ARGV;
        return -t *ARGV;
    }
    else {
        return -t *STDIN;
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Perlinstall - is installation script that installs Perl using plenv. If you have sudo permissions it also installs git and "Development tools" for you.

=head1 SYNOPSIS

 Perlinstall --mode=install_perl

 #full log
 Perlinstall --mode=install_perl -v -v 

=head1 DESCRIPTION

 Perlinstall is installation script that installs Perl using plenv (automatic install). If you have sudo permissions you can alos install extra stuff like git.

 --mode=install_perl		installs latest Perl with perlenv and cpanm
 --verbose, -v				enable verbose output (can be used twice) 

 For help write:
 Perlinstall -h
 Perlinstall -m


=head1 LICENSE

Copyright (C) Martin Sebastijan Šestak.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

mocnii E<lt>msestak@irb.hrE<gt>

=head1 EXAMPLE

=cut

