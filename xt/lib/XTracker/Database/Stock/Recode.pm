package XTracker::Database::Stock::Recode;
use NAP::policy "tt", 'class';

=head1 NAME

XTracker::Database::Stock::Recode

=head1 DESCRIPTION

Magical stock destruction and creation

=cut

with
    'XTracker::Role::WithIWSRolloutPhase',
    'XTracker::Role::WithPRLs',
    'XTracker::Role::WithAMQMessageFactory',
    'XTracker::Role::WithSchema';

use XTracker::Constants::FromDB qw( :flow_status :stock_action );
use XTracker::Database::Logging qw( log_stock );
use XTracker::Database::Stock   qw( get_transit_stock );
use MooseX::Params::Validate;
use XT::Data::Types qw/PosInt/;
use NAP::XT::Exception::Recode::FromChannelMismatch;
use NAP::XT::Exception::Recode::ToChannelMismatch;
use NAP::XT::Exception::Recode::ThirdPartySkuRequired;
use NAP::XT::Exception::Recode::NotEnoughTransitStock;

has operator_id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has 'transit_stock' => (
    is      => 'ro',
    isa     => 'HashRef',
    traits  => ['Hash'],
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $transit_list = get_transit_stock( $self->schema->storage->dbh() );

        my $allowed = {};
        foreach my $channel (keys %$transit_list) {
            # We're assuming a sku will only have transit stock on one channel
            # This may not be strictly true right now but it will be after WHM-284 is done
            foreach my $index (sort keys %{$transit_list->{$channel}}) {
                my $allowed_item = $transit_list->{$channel}->{$index};
                $allowed->{$allowed_item->{variant_id}} =
                    $allowed->{$allowed_item->{variant_id}}
                    || (0 + $allowed_item->{'quantity'})
                ;
            }
        }
        return $allowed;
    },
    handles   => {
        get_transit_stock_for_variant_id => 'get',
    },
);

=head1 PUBLIC METHODS

=head2 recode

Magically turn stock in to different stock.
All stock must come from the same channel, and for stock belonging to a 'fulfilment-only'
channel, the variants must all have third-party-skus (e.g they have had a purchase-order)

Both the 'from' and 'to' parameters are optional. This allows the creation of stock from
nothing and the destruction of stock without any new stock being created if necessary

param - from : Arrayref of stock-hash-definitions (see below) that will be destroyed
param - to : Arrayref of stock-hash-definitions (see below) that will be created
param - notes : A string containing any notes that should be applied to the log of
    the stock destroyed (note NOT the stock created)
param - force : (Default 0) If set to 1, this will force the destruction of the 'from'
    stock through even if the there is not enough stock or even if it doesn't exist!

A stock-hash-definition is a hashref with the following keys:
    variant : A dbic-variant row for the SKU we want to recode
    quantity : The amount of the SKU to recode

return - recode_objs : An array ref of stock-recode objects that have been created as a
    result of this recode

=cut
sub recode {
    my ($self, $from, $to, $notes, $force) = validated_list(\@_,
        from    => { isa => 'ArrayRef[HashRef]', default => [], optional => 1 },
        to      => { isa => 'ArrayRef[HashRef]', default => [], optional => 1 },
        notes   => { isa => 'Maybe[Str]', optional => 1 },
        force   => { isa => 'Int', optional => 1, default => 0 },
        MX_PARAMS_VALIDATE_NO_CACHE => 1,
    );

    validated_list([%$_],
        variant     => { isa => 'XTracker::Schema::Result::Public::Variant'},
        quantity    => { isa => PosInt },
        MX_PARAMS_VALIDATE_NO_CACHE => 1,
    ) for (@$from, @$to);

    # Ensure all variants we are coming FROM have the same channel
    my $from_channel = $self->_check_for_common_destroy_channel($from);

    # Ensure all 'to' variants match the 'from' channel, and on 'fulfilment_only'
    # channels the variant has a third-party-sku
    $self->_check_for_common_create_channel($to, $from_channel);

    # Make sure there is enough of all the stock we are about to destroy
    $self->_check_transit_stock($from) unless $force;

    # Looking good,time for some recoding
    my $recode_objs = [];
    $self->schema->txn_do(sub {
        $self->_destroy({
            %$_,
            notes => $notes,
            force => $force,
        }) for @$from;

        for my $data_to_create (@$to) {
            push @$recode_objs, $self->_create({
                %$data_to_create,
                notes => $notes,
            });
        }
    });

    return $recode_objs;
}

# Ensure all the stock we are about to destroy is currently sold on the same channel
sub _check_for_common_destroy_channel {
    my ($self, $from_data) = @_;

    my $from_channel;
    for my $variant_from (@$from_data) {
        my $variant_channel = $variant_from->{variant}->current_channel();
        $from_channel //= $variant_channel;
        NAP::XT::Exception::Recode::FromChannelMismatch->throw({
            variant             => $variant_from->{variant},
            expected_channel    => $from_channel,
        }) unless $from_channel->id() == $variant_channel->id();
    }
    return $from_channel;
}

# If a $destroy_channel is passed then this will ensure that not only do the
# 'create' variants all have a common channel, but that it matches that one
sub _check_for_common_create_channel {
    my ($self, $to_data, $destroy_channel) = @_;

    for my $variant_to (@$to_data) {
        my $current_channel = $variant_to->{variant}->current_channel();
        $destroy_channel //= $current_channel;
        NAP::XT::Exception::Recode::ToChannelMismatch->throw({
            variant             => $variant_to->{variant},
            expected_channel    => $destroy_channel,
        }) unless $current_channel->id() == $destroy_channel->id();

        NAP::XT::Exception::Recode::ThirdPartySkuRequired->throw({
            variant             => $variant_to->{variant},
        }) if $destroy_channel->is_fulfilment_only()
            && !$variant_to->{variant}->get_third_party_sku();
    }
    return 1;
}

# Make sure we have enough of the stock we are about to destroy
sub _check_transit_stock {
    my ($self, $destroy_variant_data) = @_;

    my $bad_variants = {};
    for my $variant_data (@$destroy_variant_data) {
        my $stock_for_variant =
            $self->get_transit_stock_for_variant_id($variant_data->{variant}->id()) // 0;
        $bad_variants->{$variant_data->{variant}->sku()} = $variant_data->{quantity}
            if $variant_data->{quantity} > $stock_for_variant;
    }

    NAP::XT::Exception::Recode::NotEnoughTransitStock->throw({
        bad_variants => $bad_variants,
    }) if (keys %{$bad_variants//{}} > 0);

    return 1;
}

# Blow up some stock
sub _destroy {
    my ($self, $variant, $quantity, $notes, $force) = validated_list(\@_,
        variant     => { isa => 'XTracker::Schema::Result::Public::Variant'},
        quantity    => { isa => PosInt },
        notes       => { isa => 'Maybe[Str]', optional => 1 },
        force   => { isa => 'Int', optional => 1, default => 0 },
    );

    my $transit_status;
    if ($self->prl_rollout_phase) {
        $transit_status = $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS;
    } elsif ($self->iws_rollout_phase) {
        $transit_status = $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS;
    } else {
        die "Cannot destroy stock unless in IWS or PRL phase";
    }

    my $channel_id = $variant->current_channel->id();
    $self->schema->resultset('Public::Quantity')->move_stock({
        variant         => $variant->id,
        channel         => $channel_id,
        quantity        => $quantity,
        from            => {
            location => 'Transit',
            status   => $transit_status,
        },
        to              => undef,
        log_location_as => $self->operator_id(),
        force           => $force,
    });

    log_stock($self->schema->storage->dbh, {
        "variant_id"  => $variant->id(),
        "action"      => $STOCK_ACTION__RECODE_DESTROY,
        "quantity"    => -1 * $quantity,
        "operator_id" => $self->operator_id(),
        "notes"       => $notes || "Destroying stock for recode operation",
        "channel_id"  => $channel_id,
    });
}

# Magic some new stock out of no-where
sub _create {
    my ($self, $variant, $quantity, $notes) = validated_list(\@_,
        variant     => { isa => 'XTracker::Schema::Result::Public::Variant'},
        quantity    => { isa => PosInt },
        notes       => { isa => 'Maybe[Str]', optional => 1 },
    );

    # Create the stock_recode records
    my $recode_row = $self->schema->resultset('Public::StockRecode')->create({
        variant_id => $variant->id(),
        quantity => $quantity,
        complete => 0,
        # this is like the "returns container" for pre-advice,
        # we're not currently using it
        container => undef,
        # remember the notes so we can add to the log later
        notes => $notes,
    });

    if ($self->iws_rollout_phase()) {
        # Send Pre-Advice to IWS
        $self->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::PreAdvice',{
            sr => $recode_row,
        });
    }
    # We don't send any messages to PRLs here, because that happens
    # after Putaway Prep.

    return $recode_row;
}

1;
