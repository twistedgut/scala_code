package XT::JQ::DC::FailedJob;

use Moose;

use DateTime;
use DateTime::Format::Epoch::Unix;
use Sys::Hostname;

use XTracker::Database qw( get_database_handle );
use XTracker::EmailFunctions qw( send_email );
use XTracker::Config::Local qw( config_var jq_failed_email );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

with 'XT::Common::JQ::FailedJob';

sub _build_schema {
    my $self    = shift;
    return get_database_handle( { name => 'jobqueue_schema' } );
}

sub app_instance_name { 'XTDC' }

sub send_failure_email {
    my ( $self, $args ) = @_;

    # get basics about the system we're on
    my $xt_instance = config_var("XTracker","instance");
    my $xt_dc_name = config_var("DistributionCentre","name");

    my $status;

    foreach ( @{ jq_failed_email() } ) {
        my $tmp_status  = 0;
        $tmp_status     = send_email( lc("xt.$xt_instance.$xt_dc_name\@net-a-porter.com"),"",$_, $args->{subject}, $args->{message} );
        $status = 1     if ( $tmp_status == 1 );
    }

    if ( $status == 1 ) {
        return ();
    }
    else {
        return ("Error Sending Email, Status: $status");
    }
}

1;


=head1 NAME

XT::JQ::DC::FailedJob - Looks for FailedJobs

=head1 DESCRIPTION

This will get any job that has failed and email the Perl team detailing the failure.
