#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use File::Slurp;
use URI;
use POSIX;
use lib 't/lib';
use FindBin::libs qw( base=lib_dynamic );
use Test::XT::URLCoverage::Handlers;

# Where are we, for starters...
my $base   = $ENV{'XTDC_BASE_DIR'};

# Set up the locations by shallow-parsing conf/xt_location.conf
my @locations;
my $current_location;

my %opts;
for my $arg (@ARGV) {
    if ( $arg =~ s/^-// ) {
        $opts{$arg} = 1;
    } else {
        $opts{'path'} = $arg;
    }
}
$opts{'v'} = 1 if POSIX::isatty(\*STDOUT);
my $lt = (POSIX::isatty(\*STDOUT) ? "\n" : '');

usage(0) if $opts{'?'} || $opts{'h'};

my $handlers_object = Test::XT::URLCoverage::Handlers->new();
$handlers_object->load();

@locations = @{ $handlers_object->entries };

# Turn the input in to a URL
my $path = URI->new( $opts{'path'} )->path;
usage(1) unless $path;

# Find the handler itself by finding the last location that matches it
debug( "URL  : $path" );
my $handler;
my $location = $handlers_object->search( $path );

if ( $location ) {
    debug( 'Match: ' . $location->{'location'} );
    debug( 'Class: ' . $location->{'handler'} );
    debug( 'Path : ' . $location->{'lib_path'} );
    $handler = $location->{'lib_path'};
}

# Noisily complain if we didn't find anything
unless ($handler) {
    print STDERR "No handler match found for [$opts{'path'}]\n";
    exit 1;
}

# Exit now unless they want the template too...
unless ( $opts{'t'} ) {
    print $handler . $lt;
    exit(0);
}

# Template nodes
print $_ . $lt for $handlers_object->templates( $location );

# Debu
sub debug {
    print $_[0] . "\n" if $opts{'v'};
}

# Usage info
sub usage {
    print "script/handler_search.pl [-t -v] http://etc\n";
    print "\t-t Attempt to find the template\n";
    print "\t-v Debugging output\n";
    print "\t-? / -h Usage\n\n";
    print "Debugging output is turned on if you are outputting to a terminal\n";
    exit($_[0]);
}

__END__

=pod

=head1 NAME

script/handler_search.pl

=head1 DESCRIPTION

Something someone wrote to find something

=head1 USAGE

As described on IRC:

    11:44 < pete> will1: script/handler_search.pl 
    11:44 < pete> will1: Useful XT tool
    11:45 < will1> pete: that script has no perldoc. what does it do?
    11:45 < pete> will1: perl script/handler_search.pl 
                http://xtdc2-dc2a.dave.net-a-porter.com/CustomerCare/OrderSearch
    11:46 < pete> You can add -t to try and get it to search for the TT template too
    11:46 < will1> cool :)

We're sure the original author will improve the documentation shortly.

=head1 AUTHOR

Peter Sergeant

=cut
