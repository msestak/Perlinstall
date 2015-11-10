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
use File::Copy;
use Exporter qw/import/;

our $VERSION = "0.001";

our @EXPORT_OK = qw{
  run
  get_parameters_from_cmd
  _capture_output
  _exec_cmd
  install_perl
  _install_prereq
  _is_interactive
  prompt

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
			my $t0 = time;
			print "RUNNING ACTION for mode: $mode\n";

            $dispatch{$mode}->( $param_href );

			my $t1 = time;
			my $elapsed = $t1 - $t0;
			print "TIME when finished for: $mode is:$elapsed sec\n";
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
	$cli{cperl}   = 0;

	#mode, quiet and verbose can only be set on command line
    GetOptions(
        'help|h'        => \$cli{help},
        'man|m'         => \$cli{man},
        'perl|c=s'      => \$cli{perl},       #Perl to install
        'cperl|c'       => \$cli{cperl},      #flag
        'threads|t=s'   => \$cli{threads},    #flag
        'migrate|m'     => \$cli{migrate},    #flag
        'infile|if=s'   => \$cli{infile},
        'out|o=s'       => \$cli{out},
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
# Usage      : my ($stdout, $stderr, $exit) = _capture_output( $cmd, $param_href );
# Purpose    : accepts command, executes it, captures output and returns it in vars
# Returns    : STDOUT, STDERR and EXIT as vars
# Parameters : ($cmd_to_execute)
# Throws     : 
# Comments   : second param is verbose flag (default off)
# See Also   :
sub _capture_output {
    croak( '_capture_output() needs a $cmd' ) unless (@_ ==  2 or 1);
    my ($cmd, $param_href) = @_;

    my $verbose = defined $param_href->{verbose}  ? $param_href->{verbose}  : 0;   #default is silent
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
# Usage      : _exec_cmd($cmd_git, $param_href);
# Purpose    : accepts command, executes it and checks for success
# Returns    : prints info
# Parameters : ($cmd_to_execute, $param_href)
# Throws     : 
# Comments   : second param is verbose flag (default off)
# See Also   :
sub _exec_cmd {
	croak( '_exec_cmd() needs a $cmd' ) unless (@_ == 2 or 3);
    my ($cmd, $param_href, $cmd_info) = @_;
	if (!defined $cmd_info) {
		($cmd_info)  = $cmd =~ m/\A(\w+)/;
	}

    my ($stdout, $stderr, $exit) = _capture_output( $cmd, $param_href );
    if ($exit == 0 ) {
        print "$cmd_info success!\n";
    }
	else {
        print "$cmd_info failed!\n";
	}
	return $exit;
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
	my $t0 = time;

	#install prerequisites for Perl installation (git, make, and gcc)
	my %flags = _install_prereq($param_href);

    #check existing Perl version
	my $cmd_perl_old = q{perl -v};
    $flags{old_perl} = _check_perl_version($param_href, $cmd_perl_old);

	#check if plenv installed
	%flags = _install_plenv($param_href, \%flags);

	#list all perls available (on verbose only)
	if ($flags{plenv} == 1 or $flags{plenv_profile} == 1) {
		my $cmd_list_perls = q{$SHELL -lc "plenv install --list"};
		my ($stdout_list, $stderr_list, $exit_list) = _capture_output( $cmd_list_perls, $param_href );
		if ($verbose == 1) {
			print "$stdout_list\n";
		}
	}

	#install cperl if requested (without threads only)
	%flags = _install_cperl($param_href, \%flags);
	
	#ask to choose which Perl to install
	%flags = _install_perl_ver($param_href, \%flags);
	
	#check if right Perl installed
	my $cmd_perl_new = q{$SHELL -lc "perl -v"};
    $flags{new_perl} = _check_perl_version($param_href, $cmd_perl_new);
	if ($flags{new_perl} eq $flags{old_perl}) {
		print "We didn't switch from $flags{old_perl} to newly installed $flags{new_perl}\n";
	}
	else {
		print "We switched from $flags{old_perl} to newly installed $flags{new_perl}\n";
	}
	
	#install cpanm to installed Perl
	%flags = _install_cpanm($param_href, \%flags);

	#ask to migrate modules from old Perl to new Perl
	my $cmd_mig = qq{plenv migrate-modules -n $flags{old_perl} $flags{new_perl}};
	print "To migrate modules from old Perl to new Perl run:\n$cmd_mig\n";

	#print time before exit because of exec call
	my $t1 = time;
	my $elapsed = $t1 - $t0;
	print "TIME when finished: $elapsed sec\n";

	#restarting shell to see new perl
	print "Restarting shell to see new Perl...\n";
	my $cmd_shell = exec( '$SHELL -l' );

    return;
}


### INTERNAL UTILITY ###
# Usage      : _install_prereq()
# Purpose    : installs prerequisites for installing Perl (git, gcc, make)
# Returns    : hash with flags
# Parameters : $param_href
# Throws     : dies if not sudo permissions
# Comments   : first part of install_perl() mode
# See Also   : install_perl() mode
sub _install_prereq {
    die('_install_prereq() needs $param_href') unless @_ == 1;
    my ($param_href) = @_;
	my %flags;

	if ($param_href->{sudo}) {
		print "Working with sudo permissions!\n";
	}
	else {
		print "Working without sudo, which is fine if you have git and essential build tools like gcc and make...).\n";
	}

	#install prerequisites for plenv
	$flags{installer} = do {
		if    (-e '/etc/debian_version') { 'apt-get' }
		elsif (-e '/etc/centos-release') { 'yum' }
		elsif (-e '/etc/redhat-release') { 'yum' }
		else                             { 'yum' }
	};

	#install git, basic Development tools
	$flags{git} = 0;
    my $cmd_check_git = 'git --version';
    my ($stdout_check_git, $stderr_check_git, $exit_check_git) = _capture_output( $cmd_check_git, $param_href );
	if ($exit_check_git == 0) {
		$flags{git} = 1;
		print "Great. You have git.\n";
	}
	$flags{gcc} = 0;
    my $cmd_check_gcc = 'gcc --version';
    my ($stdout_check_gcc, $stderr_check_gcc, $exit_check_gcc) = _capture_output( $cmd_check_gcc, $param_href );
	if ($exit_check_gcc == 0) {
		$flags{gcc} = 1;
		print "Great. You have gcc.\n";
	}
	$flags{make} = 0;
    my $cmd_check_make = 'make --version';
    my ($stdout_check_make, $stderr_check_make, $exit_check_make) = _capture_output( $cmd_check_make, $param_href );
	if ($exit_check_make == 0) {
		$flags{make} = 1;
		print "Great. You have make. Continuing with plenv install.\n";
	}

	#install git and development tools if missing
	if ($flags{git} == 0) {
		if ($param_href->{sudo} == 1) {
			my $cmd_git = "sudo $flags{installer} -y install git";
			my $exit_git = _exec_cmd($cmd_git, $param_href, 'git install');
			$flags{git} = 1 if $exit_git == 0;
		}
		else {
			die "git missing. You should first install git or try again with --sudo option if you have sudo permissions :)";
		}
	}
	if ($flags{gcc} == 0 or $flags{make} == 0) {
		if ( ($param_href->{sudo} == 1) and ($flags{installer} eq 'yum') ) {
			my $cmd_tools = q{sudo yum -y groupinstall "Development tools"};
			my $exit_tools = _exec_cmd($cmd_tools, $param_href, 'Development tools install');
			if ($exit_tools == 0) { $flags{gcc} = 1; $flags{make} = 1;}
		}
		elsif ( ($param_href->{sudo} == 1) and ($flags{installer} eq 'apt-get') ) {
			my $cmd_tools = q{sudo apt-get install build-essential};
			my $exit_tools = _exec_cmd($cmd_tools, $param_href, 'build-essential tools install');
			if ($exit_tools == 0) { $flags{gcc} = 1; $flags{make} = 1;}
		}
		else {
			if ($flags{gcc} == 0) {
				die "gcc missing. You should first install gcc or try again with --sudo option if you have sudo permissions :)";
			}
			else {
				die "make missing. You should first install make or try again with --sudo option if you have sudo permissions :)";
			}
		}
	}

    return %flags;
}

### INTERNAL UTILITY ###
# Usage      : _check_perl_version()
# Purpose    : checks Perl version installed and currently active
# Returns    : Perl version
# Parameters : $param_href
# Throws     : notices
# Comments   : part of install_perl() mode
# See Also   : install_perl() mode
sub _check_perl_version {
    die('_check_perl_version() needs $param_href') unless @_ == 2;
    my ($param_href, $cmd_perl_ver) = @_;

	my $perl_installed;
    my ($stdout_perl_ver, $stderr_perl_ver, $exit_perl_ver) = _capture_output( $cmd_perl_ver, $param_href );
    if ($exit_perl_ver == 0) {
        if ( $stdout_perl_ver =~ m{v(\d+\.(\d+)\.\d+)}g ) {
            $perl_installed = $1;
            print "We have Perl $perl_installed installed.\n";
		}
		else {
			print "Couldn't find Perl version.\n";
		}
	}
	else {
		print "Strange. Perl is not installed. No problem, we will fix that in a moment.\n";
	}

	return $perl_installed;
}


### INTERNAL UTILITY ###
# Usage      : _install_plenv()
# Purpose    : installs plenv and Perl-Build using git and updates config
# Returns    : hash with flags
# Parameters : ($param_href, $flags_href)
# Throws     : 
# Comments   : second part of install_perl() mode
# See Also   : install_perl() mode
sub _install_plenv {
    die('_install_plenv() needs $param_href') unless @_ == 2;
    my ($param_href, $flags_href) = @_;
	my %flags = %{$flags_href};

	#check if plenv installed
	$flags{plenv} = 0;
    my $cmd_plenv_ver = 'plenv --version';
    my ($stdout_plenv_ver, $stderr_plenv_ver, $exit_plenv_ver) = _capture_output( $cmd_plenv_ver, $param_href );
    if ($exit_plenv_ver == 0) {
        print "We have $stdout_plenv_ver";
		$flags{plenv} = 1;
	}
	else {
		print "plenv is not installed, installing now...\n";
	}

    #start perlenv install
	if ($flags{plenv} == 0) {
	    my $cmd_plenv = 'git clone git://github.com/tokuhirom/plenv.git ~/.plenv';
		my $exit_plenv = _exec_cmd($cmd_plenv, $param_href, 'plenv install');
		if ($exit_plenv == 0) {
			$flags{plenv} = 1;
		}
	}

	#check if Perl-Build plugin for plenv installed
	$flags{perl_build} = 0;
	my $perl_build_dir = catdir("$ENV{HOME}", '/.plenv/plugins/perl-build');
	if (-d $perl_build_dir and -s $perl_build_dir) {   #directory exists and is not empty
		$flags{perl_build} = 1;
		print "Perl-Build is installed.\n";
	}
	else {
		print "Perl-Build is not installed, installing now...\n";
	}

	#installing Perl-Build plugin for install function in plenv
	if ( ($flags{plenv} == 1) and ($flags{perl_build} == 0) ) {
		my $cmd_perl_build = q{git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/};
		my $exit_perl_build = _exec_cmd($cmd_perl_build, $param_href, 'Perl-Build install');
		if ($exit_perl_build == 0) {
			$flags{perl_build} = 1;
		}
	}

	#checking if plenv settings in place
	my $bash_profile;
	if ($flags{installer} eq 'yum') {   #on CentOS
		$bash_profile = catfile("$ENV{HOME}", '.bash_profile');
	}
	else {   #on Ubuntu
		$bash_profile = catfile("$ENV{HOME}", '.profile');
	}
	open my $fh, "<", $bash_profile or die "can't open $bash_profile:$!";
	my $prof = do {local$/; <$fh>};
	(my $plenv_match) = $prof =~ m/plenv/;

	#updating .bash_profile for plenv to work
	$flags{plenv_profile} = 0;
	if (!defined $plenv_match) {
		my ($cmd_path, $cmd_eval, $cmd_exec);
		if ($flags{installer} eq 'yum') {   #on CentOS
			$cmd_path = q{echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> ~/.bash_profile};
			$cmd_eval = q{echo 'eval "$(plenv init -)"' >> ~/.bash_profile};
			$cmd_exec = q{source $HOME/.bash_profile};
		}
		else {   #on Ubuntu
			$cmd_path = q{echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> ~/.profile};
			$cmd_eval = q{echo 'eval "$(plenv init -)"' >> ~/.profile};
			$cmd_exec = q{source $HOME/.profile};
		}

    	_exec_cmd ($cmd_path, $param_href, 'export PATH');
    	_exec_cmd ($cmd_eval, $param_href, 'plenv init');
		sleep 1;
    	_exec_cmd ($cmd_exec, $param_href, 'sourcing .bash_profile');

		#checking if sourcing plenv worked
		my $cmd_plenv_ver2 = q{$SHELL -lc "plenv --version"};
		my ($stdout_plenv_ver2, $stderr_plenv_ver2, $exit_plenv_ver2) = _capture_output( $cmd_plenv_ver2, $param_href );
		if ($exit_plenv_ver2 == 0) {
			chomp $stdout_plenv_ver2;
			print "We have sourced $stdout_plenv_ver2.\n";
			$flags{plenv_profile} = 1;
		}
		else {
			die "Sourcing plenv didn't work.\n";
		}
	}
	else {
		print "$bash_profile is already set for plenv.\n";
	}

	return %flags;
}


### INTERNAL UTILITY ###
# Usage      : _install_cperl()
# Purpose    : installs cperl and applies hack to Safe.pm
# Returns    : hash with flags
# Parameters : ($param_href, $flags_href)
# Throws     : 
# Comments   : third part of install_perl() mode
# See Also   : install_perl() mode
sub _install_cperl {
    die('_install_cperl() needs $param_href') unless @_ == 2;
    my ($param_href, $flags_href) = @_;
	my %flags = %{$flags_href};

	#install cperl if requested (without threads only)
	$flags{perl_installed} = 0;
	if ($param_href->{cperl}) {
		#install OpenSSL library to fetch cperl archive
		my $cmd_ssl;
		if ($flags{installer} eq 'yum') {
			$cmd_ssl = qq{sudo $flags{installer} install -y openssl-devel};
		}
		else {
			$cmd_ssl = qq{sudo $flags{installer} install -y libssl-dev};
		}
		my $cmd_ssl2 = q{cpanm -n IO::Socket::SSL};
		_exec_cmd ($cmd_ssl, $param_href, "openssl developmental lib installation");
		_exec_cmd ($cmd_ssl2, $param_href, "perl module IO::Socket::SSL installation");

		#define cperl version
		if ($param_href->{perl}) {   #from --perl on command line
			$flags{cperl} = "cperl-" . "$param_href->{perl}";
		}
		else {   #default (only availabale atm)
			$flags{cperl} = 'cperl-5.22.1';
		}
		
		#build a command and install cperl
		my $cmd_cperl = qq{plenv install -j 4 -Dusedevel -Dusecperl --as $flags{cperl} https://github.com/perl11/cperl/archive/${flags{cperl}}.tar.gz};
		my ($stdout_cperl, $stderr_cperl, $exit_cperl) = _capture_output( $cmd_cperl, $param_href );
		if ($exit_cperl == 0) {
			print "Installed $flags{cperl}\n";
			
			#finish installation, set perl as global
			my $cmd_rehash = q{$SHELL -lc "plenv rehash"};
			my $cmd_global = qq{\$SHELL -lc "plenv global $flags{cperl}"};
			_exec_cmd ($cmd_rehash, $param_href, "plenv rehash");
			_exec_cmd ($cmd_global, $param_href, "Perl cperl set to global (plenv global)");

				#set through %ENV if plenv global didn't work
				if (defined $ENV{PLENV_VERSION}) {
					if ($ENV{PLENV_VERSION} eq "$flags{cperl}") {
						print "Perl $flags{cperl} set to global. Whoa:)\n";
					}
					else {
						#set it yourself
						$ENV{PLENV_VERSION} = "$flags{cperl}";
						print "Perl is now $flags{cperl}. For real this time:)\n";
					}
				}
	
			$flags{perl_installed} = 1;
		}
	}

	#hack Safe.pm to enable installation of and working cpanm
	if ($param_href->{cperl} and $flags{perl_installed} == 1) {
		(my $ver) = $flags{cperl} =~ m/\Acperl-(.+)\z/;
		my $safe_lib = catfile("$ENV{HOME}", '/.plenv/versions/', "$flags{cperl}", 'lib', "$ver", 'Safe.pm');
		if (-f $safe_lib) {
			my $safe_lib_new = $safe_lib . 'new';
			open my $fh_safe_r, "<", $safe_lib     or die "can't open $safe_lib for reading:$!";
			open my $fh_safe_w, ">", $safe_lib_new or die "can't open $safe_lib for writing:$!";

			while (<$fh_safe_r>) {
				chomp;
				if (/2.39_01c/) {
					print {$fh_safe_w} '$Safe::', 'VERSION = "2.39_02c";', "\n";   #split this line else it evaluates
				}
				elsif ( m/use Opcode 1.01, qw\(/) {
					print {$fh_safe_w} 'use Opcode qw(', "\n";
				}
				else {
					print {$fh_safe_w} "$_\n";
				}
			}
			#rename new file with old file
			move("$safe_lib_new", "$safe_lib") or die "Rename failed: $!";
			print "$safe_lib modified. Try to install cpanm.\n";
		}
		else {
			print "$safe_lib not found.\n";
		}
	}

	return %flags;
}


### INTERNAL UTILITY ###
# Usage      : _install_perl_ver()
# Purpose    : installs Perl version required
# Returns    : hash with flags
# Parameters : ($param_href, $flags_href)
# Throws     : 
# Comments   : 4th part of install_perl() mode
# See Also   : install_perl() mode
sub _install_perl_ver {
    die('_install_perl_ver() needs $param_href') unless @_ == 2;
    my ($param_href, $flags_href) = @_;
	my %flags = %{$flags_href};

	#ask to choose which Perl to install
	my $cmd_install;
	if ($flags{perl_installed} == 0 and ($flags{plenv} == 1 or $flags{plenv_profile} == 1) ) {

		#prompt for Perl version if not given on command prompt
		if (!$param_href->{perl}) {
			$param_href->{perl} = prompt ('Choose which Perl version you want to install>', '5.22.0');
		}

		#prompt for threads option if not given on command prompt
		if (!$param_href->{threads}) {
			$param_href->{threads} = prompt ('Do you want to install Perl with {usethreads} or without threads {nothreads}?>', 'nothreads');
		}

		#make install command
		if ($param_href->{threads} eq 'nothreads') {
			$cmd_install = qq{\$SHELL -lc "plenv install -j 4 -Dcc=gcc $param_href->{perl}"};
		}
		else {
			$cmd_install = qq{\$SHELL -lc "plenv install -j 4 -Dcc=gcc -D usethreads $param_href->{perl}"};
		}

		#install Perl
		my ($stdout_perl, $stderr_perl, $exit_perl) = _capture_output( $cmd_install, $param_href );
		if ($exit_perl == 0) {
			$flags{perl_installed} = 1;
			print "Installed Perl-", "$param_href->{perl}\n";
		
			#finish installation, set perl as global
			my $cmd_rehash = q{$SHELL -lc "plenv rehash"};
			my $cmd_global = qq{\$SHELL -lc "plenv global $param_href->{perl}"};
			_exec_cmd ($cmd_rehash, $param_href, "plenv rehash");
			_exec_cmd ($cmd_global, $param_href, "Perl $param_href->{perl} set to global (through plenv global)");
	
			#set through %ENV if plenv global didn't work
			if (defined $ENV{PLENV_VERSION}) {
				if ($ENV{PLENV_VERSION} eq $param_href->{perl}) {
					#print "Perl $param_href->{perl} set to global. Whoa:)\n";
				}
				else {
					#set it yourself
					$ENV{PLENV_VERSION} = $param_href->{perl};
					print "Perl $param_href->{perl} set to global (ENV manipulation).\n";
				}
			}
		}
	}


	return %flags;
}


### INTERNAL UTILITY ###
# Usage      : _install_cpanm()
# Purpose    : installs cpanm to Perl version just installed
# Returns    : hash with flags
# Parameters : ($param_href, $flags_href)
# Throws     : 
# Comments   : 4th part of install_perl() mode
# See Also   : install_perl() mode
sub _install_cpanm {
    die('_install_cpanm() needs $param_href') unless @_ == 2;
    my ($param_href, $flags_href) = @_;
	my %flags = %{$flags_href};

	#install cpanm to installed Perl (and not cperl)
	$flags{cpanm} = 0;
	if ($flags{perl_installed} == 1 and $param_href->{cperl} == 0) {
		my $cmd_cpanm = q{$SHELL -lc "plenv install-cpanm"};
		my ($stdout_cpanm, $stderr_cpanm, $exit_cpanm) = _capture_output( $cmd_cpanm, $param_href );
		if ($exit_cpanm == 0) {
			$flags{cpanm} = 1;
			print "cpanm installed through plenv.\n";

			# rehash after cpanm installation
			my $cmd_rehash = q{$SHELL -lc "plenv rehash"};
			_exec_cmd ($cmd_rehash, $param_href, "plenv rehash");
		}
	}

	#install cpanm to installed cperl because cperl has bug with plenv cpanm installation. At least cperl-5.22.1.
	if ($flags{perl_installed} == 1 and $param_href->{cperl} == 1 and $flags{cpanm} == 0) {
		my $cmd_cpan = q{$SHELL -lc "yes|perl -MCPAN -e \"CPAN::Shell->notest('install', 'App::cpanminus')\""};
		my $exit_cperl_cpanm = _exec_cmd ($cmd_cpan, $param_href, "App::cpanminus install");
		if ($exit_cperl_cpanm == 0) {
			$flags{cpanm} = 1;
			print "cpanm installed through cpan client for cperl.\n";
		}

		# rehash after cpanm installation
		my $cmd_rehash = q{$SHELL -lc "plenv rehash"};
		_exec_cmd ($cmd_rehash, $param_href, "plenv rehash");
	}

	return %flags;
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

Perlinstall - is installation script (modulino) that installs Perl (or cperl) using plenv. It also installs cpanm with Perl you are installing. If you have sudo permissions it also installs git and your Linux distribution based "Development tools" for you. If you have git, gcc and make you can skip sudo.

=head1 SYNOPSIS

 #first install in clean environment
 #sudo needed to install git, gcc and make
 Perlinstall.pm --mode=install_perl --perl=5.12.1 -t nothreads --sudo

 #if git installed (prompt for perl version and threads support)
 Perlinstall --mode=install_perl

 #full verbose with threads and no prompt
 Perlinstall.pm --mode=install_perl -v -v --perl=5.20.0 --threads=usethreads

 #install cperl 5.22.1 with nothreads
 ./Perlinstall.pm --mode=install_perl --cperl --perl=5.22.1

=head1 DESCRIPTION

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

=head1 ACKNOWLEDGMENTS

The subs prompt() and _is_interactive() are borrowed from L<IO::Prompt::Tiny> (copied and not required because I couldn't afford non-core dependency). The are based on L<ExtUtils::MakeMaker> and L<IO::Interactive::Tiny> (which is based on L<IO::Interactive>). Thank you to the authors of those modules.

=head1 LICENSE

Copyright (C) Martin Sebastijan Šestak.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Martin Sebastijan Šestak E<lt>msestak@irb.hrE<gt>

=head1 EXAMPLE

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
 
=cut

