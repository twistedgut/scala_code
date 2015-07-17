package XTracker::Schema::ResultSet::Public::ChannelTransfer;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use XTracker::Constants::FromDB qw( :channel_transfer_status );

sub between_selected_and_completed {
    my ($self) = @_;
    my $alias = $self->current_source_alias;

    return $self->search({
        status_id => { -in => [
            $CHANNEL_TRANSFER_STATUS__SELECTED,
            $CHANNEL_TRANSFER_STATUS__INCOMPLETE_PICK,
            $CHANNEL_TRANSFER_STATUS__PICKED,
        ] },
    });
}

sub product_ids {
    my ($self) = @_;
    my $alias = $self->current_source_alias;

    return $self->search(
        {},
        {
            columns => [ 'product_id' ],
            distinct => 1,
        }
    );
}

1;
