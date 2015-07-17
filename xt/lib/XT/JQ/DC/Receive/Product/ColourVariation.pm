package XT::JQ::DC::Receive::Product::ColourVariation;

use Moose;

use Data::Dump qw/pp/;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose        qw( Str Int ArrayRef HashRef);
use MooseX::Types::Structured   qw( Dict );

use XTracker::Comms::DataTransfer       qw( :transfer_handles );
use XTracker::Comms::FCP qw( create_fcp_related_product delete_fcp_related_product );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

has channels => (
    is => 'rw',
    isa => HashRef,
    lazy_build => 1,
);

has payload => (
    is  => 'ro',
    isa => Dict[
        action  => enum([qw/add delete/]),
        pid1    => Int,
        pid2    => Int,
    ],
    required => 1,
);

sub _build_channels {
    my $self = shift;
    $self->schema->resultset('Public::Channel')->get_channels({ fulfilment_only => 0 });
}

# We want to help people out who try and update a product, that's part of a
# product upload, before that product has made it to the DC
sub max_retries { return 10 }
sub retry_delay { return 60 * 10 }

sub check_job_payload {
    my $payload = shift->payload;
    return ('Cannot link product to itself')
        if ($payload->{action} eq 'add' && $payload->{pid1} == $payload->{pid2});
    return ();
}

sub do_the_task {
    my ($self, $job)    = @_;

    my $payload  = $self->payload;
    my $channels = $self->channels;

    my $web_dbhs;
    my $fail_action = 'die';

    eval {
        # get web dbh
        foreach my $cid (keys %$channels){
            eval {
                $web_dbhs->{$cid} = get_transfer_sink_handle({
                    environment => 'live',
                    channel => $channels->{$cid}{config_section},
                });
            };
            if ( $@ || (!defined $web_dbhs->{$cid}->{dbh_sink}) ) {
                $fail_action = 'retry';
                die "Can't Talk to Web Site for Channel "
                    .$cid." (".$channels->{$cid}{config_section}.") - ".$@;
            };
        }

        # NOTE: We do NOT need to update the colour variation in DC
        # - it's mastered in Fulcrum now and
        # MIS don't need recommended_produccts stored here

        # need to update website for all channels in this DC
        # No need to wrap in an xtracker transaction as we're not updating XT DB
        my $channels = $self->channels;
        my $pid1 = $payload->{pid1};
        my $pid2 = $payload->{pid2};
        foreach my $cid (keys %$channels){
            if ($payload->{action} eq 'add'){
                # skip if both pids are not live
                next unless $self->schema->resultset('Public::ProductChannel')->pids_live_on_channel($cid, [$pid1, $pid2]);
                # create links on website
                create_fcp_related_product(
                    $web_dbhs->{$cid}->{dbh_sink},
                    { product_id => $pid1,
                      related_product_id => $pid2,
                      type_id => 'COLOUR', }
                );
                create_fcp_related_product(
                    $web_dbhs->{$cid}->{dbh_sink},
                    { product_id => $pid2,
                      related_product_id => $pid1,
                      type_id => 'COLOUR', }
                );
            } elsif ($payload->{action} eq 'delete'){
                # delete links on website
                delete_fcp_related_product(
                    $web_dbhs->{$cid}->{dbh_sink},
                    { product_id => $pid1,
                      related_product_id => $pid2,
                      type_id => 'COLOUR', }
                );
                delete_fcp_related_product(
                    $web_dbhs->{$cid}->{dbh_sink},
                    { product_id => $pid2,
                      related_product_id => $pid1,
                      type_id => 'COLOUR', }
                );
            }
        }

        # commit all the changes
        $web_dbhs->{$_}->{dbh_sink}->commit() foreach keys %$web_dbhs;
        $web_dbhs->{$_}->{dbh_sink}->disconnect() foreach keys %$web_dbhs;
    };
    if (my $err = $@){
        #rollback & disconnect for the web
        $web_dbhs->{$_}->{dbh_sink}->rollback() foreach keys %$web_dbhs;
        $web_dbhs->{$_}->{dbh_sink}->disconnect() foreach keys %$web_dbhs;

        $fail_action  = "retry" if $err =~ /Deadlock/;
        if ( $fail_action eq "retry" ) {
            $job->failed( $err );
        } else {
            die $err;
        }
    }
}



1;


=head1 NAME

XT::JQ::DC::Receive::Product::ColourVariation - Add/Delete colour variation links

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::Product::ColourVariation message when
products linked/unlinked as colour variants

Expected Payload should look like:

Dict[
    action  => enum(qw/add remove/),
    pid1    => Int,
    pid2    => Int,
],
