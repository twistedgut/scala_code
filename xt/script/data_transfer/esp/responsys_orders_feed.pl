#!/opt/xt/xt-perl/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Getopt::Long;
use Pod::Usage;


use XTracker::Script::Extract::ESP;


my %cli;
my $result  = GetOptions( \%cli,
                'path|p=s',
                'fromdate|f=s',
                'verbose|v',
                'dryrun|d',
                'help|?|h'
            );

pod2usage( -verbose => 2 )          if ( !$result || $cli{help} );

# turn 'verbose' on if 'dryrun' is on
$cli{verbose}   = 1     if ( $cli{dryrun} );

XTracker::Script::Extract::ESP->new( \%cli )->invoke();

__END__

=head1 NAME

responsys_orders_feed.pl - script to prepare the feed to pass to Responsys

=head1 SYNOPSIS

responsys_orders_feed.pl [options]

options:

-h, -?, --help
        this page

-p, --path
        specify the path the file is created in. If unspecified,
        the script will use the path set in the xtracker conf file

-f, --fromdate
        specify the date the script will extract the orders from.
        Must be specified as 'YYYY-MM-DD' (default: yesterday).

-v, --verbose
        print lots of information about what's happening

-d, --dryrun
        doesn't actually write a file but shows you what would
        happen, verbose gets turned on by default with this option.

=head1 DESCRIPTION

This script will prepare a tab delimited file containing data from the DC
systems for Responsys. The script will generate the file, and another script
will take care of the encryption and pushing the file to Responsys.

=cut
