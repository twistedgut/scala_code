package XT::JQ::DC::Receive::Sample::Request;

use Moose;

use Data::Dump qw/pp/;

use MooseX::Types::Moose qw(Int ArrayRef);
use MooseX::Types::Structured qw( Dict );


use namespace::clean -except => 'meta';
use XTracker::Database::Product qw( request_product_sample );
use XTracker::Database::Channel qw( get_channels );

extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    required => 1,
    isa => ArrayRef[
            Dict[
                channel_id     => Int,
                product_id     => Int,
                operator_id    => Int,
            ]
    ]
);

sub do_the_task {
    my ($self, $job) = @_;

    my $channels = get_channels( $self->dbh );

    $self->schema->txn_do(sub{
        # process each request in payload
        foreach my $record ( @{ $self->payload } ) {
            next if !exists $channels->{ $record->{channel_id} };

            # set update date for product/channel
            request_product_sample( $self->dbh, $record->{product_id}, $record->{channel_id} );
        }
    });
}

sub check_job_payload {
    my ($self, $job) = @_;

    return ();
}

1;

=head1 NAME

XT::JQ::DC::Receive::Sample::Request - Notification of request for a sample unit
from the DC system

=head1 DESCRIPTION




