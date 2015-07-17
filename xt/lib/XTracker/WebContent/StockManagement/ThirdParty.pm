package XTracker::WebContent::StockManagement::ThirdParty;

use Moose;

with 'XTracker::WebContent::Roles::ContentManager',
    'XTracker::WebContent::Roles::StockManager',
    'XTracker::WebContent::Roles::ReservationManager',
    'XTracker::WebContent::Roles::StockManagerBroadcast',
    'XTracker::Role::WithAMQMessageFactory';
with 'XTracker::WebContent::Roles::StockManagerThatLogs';

use Carp qw( croak );

=head1 NAME

XTracker::WebContent::StockManagement::ThirdParty

=head1 DESCRIPTION

Class to update stock via AMQ message to Integration Service

=cut

has _messages => (
    is          => 'ro',
    isa         => 'ArrayRef[HashRef]',
    init_arg    => undef, # not settable in constructor
    default     => sub {[]},
    traits      => ['Array'],
    handles     => {
        _add_to_messages    => 'push',
        _get_next_message   => 'shift',
        _clear_messages     => 'clear',
    },
);

=head1 METHODS

=head2 is_mychannel

Returns true if this module can handle the channel

=cut

sub is_mychannel {
    my ($class, $channel) = @_;

    return $channel->business->fulfilment_only;
}

=head2 stock_update

Queue up the AMQ message to send

=cut

sub stock_update {
    my $self = shift;
    my $args = {
        quantity_change => undef,
        variant_id      => undef,
        @_
    };

    my $variant_id      = $args->{variant_id};
    my $quantity_change = $args->{quantity_change};
    my $variant         = $self->schema->resultset('Public::Variant')->find($variant_id);

    my $business = $self->channel->business;
    my $business_id = $business->id;
    my $third_party_sku = $self->schema->resultset('Public::ThirdPartySku')->search({
        variant_id  => $variant_id,
        business_id => $business_id
    })->first->third_party_sku;

    my $new_stock_level = $variant->product->get_saleable_item_quantity()
        ->{$business->name}->{$variant_id};

    $self->_add_to_messages({
        business    => $self->channel->business,
        status      => 'Sellable',
        location    => $self->channel->distrib_centre->name,
        quantity    => $new_stock_level,
        sku         => $third_party_sku,
    });

    return;
}

=head2 reservation_upload

Throws exception as not currently implemented over AMQ.

=cut

sub reservation_upload {
    my $self = shift;

    croak "Not implemented yet for channel: " . $self->channel->name;
}

=head2 reservation_cancel

Throws exception as not currently implemented over AMQ.

=cut

sub reservation_cancel {
    my $self = shift;

    croak "Not implemented yet for channel: " . $self->channel->name;
}

=head2 reservation_update

Throws exception as not currently implemented over AMQ.

=cut

sub reservation_update_expiry {
    my $self = shift;

    croak "Not implemented yet for channel: " . $self->channel->name;
}

=head2 commit

Send queued messages to third party

=cut

sub commit {
    my $self = shift;

    # then send an amq message
    my $amq = $self->msg_factory;

    while (my $message = $self->_get_next_message) {
        $amq->transform_and_send( 'XT::DC::Messaging::Producer::Stock::ThirdPartyUpdate', $message);
    }
}

=head2 rollback

Clear queue of messages to send

=cut

sub rollback {
    my $self = shift;

    $self->_clear_messages;
}

=head1 SEE ALSO

L<XTracker::WebContent::StockManagment>,
L<XTracker::WebContent::Roles::StockManager>

=head1 AUTHORS

Andrew Solomon <andrew.solomon@net-a-porter.com>, Pete Smith <pete.smith@net-a-porter.com>

=cut

1;

