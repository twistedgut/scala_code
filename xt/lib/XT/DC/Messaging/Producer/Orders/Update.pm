package XT::DC::Messaging::Producer::Orders::Update;
use NAP::policy "tt", 'class';
    with 'XT::DC::Messaging::Role::Producer',
         'XTracker::Role::WithIWSRolloutPhase',
         'XTracker::Role::WithPRLs',
         'XTracker::Role::WithSchema';

use Scalar::Util qw/blessed/;

sub message_spec {
    return {
        type => '//rec',
        required => {
            orderNumber => '//str',
            status => '//str',
            shippingMethod => '//str',

            orderItems  => {
                type    => '//arr',
                contents    => {
                    type        => '//rec',
                    required    => {
                        xtLineItemId => '//int',
                        sku => => '//str',
                        status => '//str',
                        unitPrice => '//num',
                        tax => '//num',
                        duty => '//num',
                    },
                    optional => {
                        notPrimaryReturn => '//str',
                        returnable => '//str',
                        returnCreationDate => '/nap/datetime',
                        returnCompletedDate => '/nap/datetime',
                        exchangeSku => '//str',
                        returnReason => '//str',
                        faultDescription => '//str',
                        orderItemNumber => '//int',
                        voucherCode => '//str',
                    },
                },
            },
        },
        optional => {
            trackingUri => '//str',
            trackingNr => '//str',
            returnCutoffDate => {
                type    => '//any',
                of      => ['/nap/datetime','//nil'],
            },
            rmaNumber => '//str',
            returnCreationDate => '/nap/datetime',
            returnExpiryDate => '/nap/datetime',
            returnCancellationDate => '/nap/datetime',
            returnRefundType => '//str',
            returnRefundAmount => '//num',
            returnRefundCurrency => '//str',
        },
    };
}

has '+type' => ( default => 'OrderMessage' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my($self, $header, $data) = @_;

    my $order;

    if ($order = $data->{order}) {

        die ref($self) . ": order passed but its not an object"
            unless blessed($order);
    } elsif (defined $data->{order_nr}) {
        my $nr = $data->{order_nr} || 0;

        $order = $self->schema->resultset('Public::Orders')->find({
            order_nr => $nr
        });

        die ref($self) . ": cannot find order with nr $nr"
            unless $order;

    } else {
        my $id = $data->{order_id} || 0;


        die ref($self) ." - order_id is not an integer or not set"
            unless ($id =~ /^[0-9]+$/ && $id <= 2147483647);

        $order = $self->schema->resultset('Public::Orders')->find($id);

        die ref($self) . ": cannot find order with id $id"
            unless $order;
    }

    if (not $order->channel) {
        die ref($self) . ": no channel for order id - ". $order->id;
    }

    # this should set the queue to something like..
    # /queue/nap-intl-orders (via the configuration)
    $header->{destination} = $order->channel->web_name;

    # we have an item specific header

    $header->{'JMSXGroupID'}= $order->channel->lc_web_name;
    $header->{'version'}    = 1;

    my $out = $order->make_order_status_message;

    return ($header,$out);
}

1;
