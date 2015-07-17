#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs       qw( base=lib_dynamic );

use Getopt::Long;
use Pod::Usage;

use XTracker::Script::DB::CreateBackFillJob;


my %cli;
my $result  = GetOptions( \%cli,
                'verbose|v',
                'dryrun|d',
                'help|?|h'
            );

pod2usage( -verbose => 2 )          if ( !$result || $cli{help} );

# turn 'verbose' on if 'dryrun' is on
$cli{verbose}   = 1     if ( $cli{dryrun} );

XTracker::Script::DB::CreateBackFillJob->new( \%cli )->invoke();

__END__

=head1 NAME

create_back_fill_jobs.pl

=head1 SYNOPSIS

fraud_hotlist_data.pl -t dc_number [options]

options:

-h, -?, --help
        this page

-v, --verbose
        print information about what's happening

-d, --dryrun
        doesn't actually do anything but shows you what would
        happen, verbose gets turned on by default with this option.

=head1 DESCRIPTION

This script will get all New or In Progress 'dbadmin.back_fill_job' records and create
the required Jobs on TheShwartz Job Queue which will then get processed and Back-fill
newly added columns to existing tables.

The JQ Worker that will process these Jobs is:

    XT::JQ::DC::Receive::DB::RunBackFillJob

=cut

