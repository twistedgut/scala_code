package Test::XTracker::Data::ChannelTransfer;
use NAP::policy "tt", 'class';
with 'XTracker::Role::WithSchema';

use MooseX::Params::Validate            qw/validated_list/;
use XTracker::Database::Product         qw/create_product_channel/;
use XTracker::Database::ChannelTransfer qw/
    set_product_transfer_status
    create_channel_transfer
/;
use XTracker::Constants::FromDB         qw/
    :product_channel_transfer_status
    :channel_transfer_status
/;
use XTracker::Constants                 qw{ :application };

sub request_channel_transfer {
    my ($self, $product, $new_channel) = validated_list(\@_,
        product     => { required => 1 },
        new_channel => { required => 1 },
    );

    my $dbh = $self->dbh();

    # set transfer status on source channel
    set_product_transfer_status($dbh, {
        product_id  => $product->id(),
        channel_id  => $product->get_product_channel->channel->id,
        status_id   => $PRODUCT_CHANNEL_TRANSFER_STATUS__REQUESTED,
        operator_id => $APPLICATION_OPERATOR_ID,
    });

    # create channel record on destination channel
    my $product_channel_id = create_product_channel($dbh, {
        product_id  => $product->id(),
        channel_id  => $new_channel->id(),
    });

    # create a channel transfer job for stock movement
    create_channel_transfer($dbh, {
        product_id      => $product->id(),
        from_channel_id => $product->get_product_channel()->channel()->id(),
        to_channel_id   => $new_channel->id(),
        operator_id     => $APPLICATION_OPERATOR_ID,
    });

    return $self->schema()->resultset('Public::ProductChannel')->find($product_channel_id);
}

sub complete_channel_transfer {
    my ($self, $product_channel) = validated_list(\@_,
        product_channel => { required => 1 },
    );

    # TODO: Plenty more that should be done, but enough for current purposes.
    # Ideally the logic for this should be properly factored out to model so
    # we just call that.
    $product_channel->update({
        transfer_status_id => $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED,
    });
    return 1;
}
