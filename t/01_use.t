#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

my $module = 'Perlinstall';
my @subs = qw( 
  run
  get_parameters_from_cmd
  _capture_output
  _exec_cmd
  install_perl
  _install_prereq
  _is_interactive
  prompt

);

use_ok( $module, @subs);

foreach my $sub (@subs) {
    can_ok( $module, $sub);
}

done_testing();
