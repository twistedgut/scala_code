package XTracker::Schema::ResultSet::Public::ProductChannel;
# vim: ts=4 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use DateTime::Format::Pg;
use Carp;

use XTracker::Utilities         qw( set_time_to_start_of_day );


=head1 NAME XTracker::Schema::ResultSet::Public::ProductChannel

=head1 METHODS

=head2 pids_live_on_channel( $channel_id, \@product_ids )

Provide a channel_id and a listref of pids as arguments. Returns true if all
products are live on that channel, else returns false

=head3 NOTE
This is purely to know if a PID will exist in a web DB. There are additional
rules to do with 'product_channel_transfer_status' if you actually want to
know if a product is really currently live on a channel.

=cut

sub pids_live_on_channel {
    my ($self, $cid, $pids) = @_;
    return @$pids == $self->search({
        product_id => { -in => $pids },
        channel_id => $cid,
        live => 1,
    })->count;
}

=head2 list_on_channel_for_upload_date

    $result_set = $self->list_on_channel_for_upload_date( $channel, $upload_date );

This will return a Result Set for a given Sales Channel for a particular Upload Date.

=cut

sub list_on_channel_for_upload_date {
    my ( $self, $channel, $upload_date )    = @_;

    if ( !$channel || ref( $channel ) !~ /::Public::Channel$/ ) {
        croak "No Channel Object has been passed into '" . __PACKAGE__ . "->list_on_channel_for_upload_date' method";
    }
    if ( !$upload_date || ref( $upload_date ) !~ /DateTime/ ) {
        croak "No DateTime Object has been passed into '" . __PACKAGE__ . "->list_on_channel_for_upload_date' method";
    }

    # make the date start at the beginning of the day
    my $date    = set_time_to_start_of_day( $upload_date );

    my $me  = $self->current_source_alias;

    return $self->search(
                    {
                        "${me}.channel_id"  => $channel->id,
                        "${me}.upload_date" => $date,
                    }
                );
}

1;
