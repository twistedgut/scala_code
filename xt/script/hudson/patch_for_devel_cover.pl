#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use File::Basename;

# Devel::Cover doesn't get on that well with Moose; an actual example of this is
# that attribute checking fails fatally under Devel::Cover where it works fine
# when run outside of Devel::Cover.
#
# An interim working solution is to patch libraries - for now, changing
# ArrayRef[Something] to just ArrayRef. We don't want to hot-patch the actual
# installed library just to run coverage statistics, but we need the coverage
# stats.
#
# This script takes one or more modules, makes local copies of them, executes
# commands on those copies, and pushes that directory to the front of libraries
# to search.


# Location of our local patched library directory
my $patches_directory = 'devel_cover_patched_libraries/';

# Libraries to poke. 'library' is the library path, 'source' is where we get
# it from. 'command' is a coderef, that's passed a copy of this hashref as a
# first argument, with the key 'target' which is the patches_directory and 
# 'library' sensibly concatenated.
my @module_specification = (
    {
        library  => 'MooseX/Traits/Pluggable.pm',
        source   => '/opt/xt/xt-perl/lib/site_perl/5.8.8/',
        commands => sub {
            my $conf = shift;
            my $target = $conf->{'target'};
            say_and_do(q!perl -p -i -e 's/ArrayRef\[\w+\]/ArrayRef/g' ! . $target);
        },
    }
);

say("Installing patched modules for Devel::Cover");

# Nuke our patches directory, just in case
say_and_do("rm -rf $patches_directory*")
    if $patches_directory =~ m/^\w.+\/$/;

# Create the patches directory unless it's there
mkdir $patches_directory unless -d $patches_directory;

for my $task (@module_specification) {
    say("Installing and patching locally " . $task->{'library'});

    # Make the destination directory if it's not already there
    my $destination_atom = (fileparse( $task->{'library'} ))[1];
    my $destination_directory = $patches_directory . $destination_atom;    
    say_and_do("mkdir -p $destination_directory") unless (-d $destination_directory);
    
    # Copy the library over
    my $destination_file = $patches_directory . $task->{'library'};
    $task->{'target'} = $destination_file;
    my $source_file = $task->{'source'} . $task->{'library'};
    say_and_do("cp $source_file $destination_file");

    # Make the changes
    $task->{'commands'}( $task );
}

sub say { print '[' . localtime() . "] $_\n" for @_;  }
sub say_and_do {
    for my $cmd (@_) {
        say( "\tExecuting: $cmd" );
        `$cmd`; ## no critic(ProhibitBacktickOperators)
    }
}

