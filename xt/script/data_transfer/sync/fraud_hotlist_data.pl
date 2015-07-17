#!/opt/xt/xt-perl/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Getopt::Long;
use Pod::Usage;


use XTracker::Script::Sync::FraudHotlist;


my %cli;
my $result  = GetOptions( \%cli,
                'batch|b=i',
                'verbose|v',
                'dryrun|d',
                'help|?|h'
            );

pod2usage( -verbose => 2 )          if ( !$result || $cli{help} );

# turn 'verbose' on if 'dryrun' is on
$cli{verbose}   = 1     if ( $cli{dryrun} );

XTracker::Script::Sync::FraudHotlist->new( \%cli )->invoke();

__END__

=head1 NAME

fraud_hotlist_data.pl - script to copy Fraud Hot List data from the local DC to others

=head1 SYNOPSIS

fraud_hotlist_data.pl -t dc_number [options]

options:

-h, -?, --help
        this page

-b, --batch
        the number of hotlist records to send via AMQ at a time,
        not specifying this options defaults to NO limit:

            fraud_hotlist_data.pl -b 1000

-v, --verbose
        print lots of information about what's happening

-d, --dryrun
        doesn't actually do anything but shows you what would
        happen, verbose gets turned on by default with this option.

=head1 DESCRIPTION

=cut
