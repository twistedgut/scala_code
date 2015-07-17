package XT::DC::Messaging::Producer::ProductService::Upload;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer',
    # these are to appease XT's message queue "custom accessors"
    'XTracker::Role::WithIWSRolloutPhase',
    'XTracker::Role::WithPRLs',
    'XTracker::Role::WithSchema';

use XTracker::Config::Local 'config_var';
use Carp qw( croak );

=head1 NAME

XT::DC::Messaging::Producer::ProductService::Upload - send the "promote to live" message

=head1 METHODS

=head2 C<message_spec>

L<Data::Rx> spec for the product promotion messages.

=cut

sub message_spec {
    return {
        type => '//rec',
        required => {
            products => {
                type => '//arr',
                length => { min => 1 },
                contents => {
                    type => '//rec',
                    required => {
                        product_id => '//int',
                        channel_id => '//int',
                    },
                },
            },
            upload_date => '//str',
            upload_timestamp => '//str',
        },
        optional => {
            add_product_tags => {
                type => '//arr',
                contents => '//str',
            },
            remove_product_tags => {
                type => '//arr',
                contents => '//str',
            },
        }
    };
}

has '+type' => ( default => 'promote_to_live' );

=head2 C<transform>

    $amq->transform_and_send( 'XT::DC::Messaging::Producer::ProductService::Upload', {
        channel_id  => $self->payload->{channel_id},
        pids        => $self->data->{pids_touse},
        upload_date => $self->payload->{due_date},
        upload_timestamp => DateTime->now->set_time_zone('UTC')->iso8601,
    } );

Given a set of PIDs and a channel_id, will send a command to the product service
to make those products live.

=cut

sub transform {
    my ($self,$header,$data) = @_;

    # Very basic argument validation
    my $chid = $data->{channel_id} // croak "Channel ID required";
    my $pids = $data->{pids} // croak "PIDs required";
    my $upload_date = $data->{upload_date} // croak "upload date required";
    my $upload_timestamp = $data->{upload_timestamp} // croak "upload timestamp required";
    my $add_product_tags = $data->{add_product_tags} // [];
    my $remove_product_tags = $data->{remove_product_tags} // [];

    # Transform the data into expected format
    my @products;
    foreach ( @{$data->{pids}} ) {
        push @products, {
            product_id => $_,
            channel_id => $chid,
        };
    }

    my $payload;
    $payload->{products}   = \@products;
    $payload->{upload_date} = $upload_date;
    $payload->{upload_timestamp} = $upload_timestamp;

    $payload->{add_product_tags} = $add_product_tags;
    $payload->{remove_product_tags} = $remove_product_tags;

    return ($header,$payload);
}
