package XT::DC::Messaging::Producer::PreOrder::Update;
use NAP::policy "tt", 'class';
use Scalar::Util qw/blessed/;
use XTracker::Constants::FromDB qw( :pre_order_item_status );
use XTracker::Utilities qw( as_zulu );
use NAP::Messaging::Validator;

NAP::Messaging::Validator->add_type_plugins(
    map {"XT::DC::Messaging::Spec::Types::$_"}
        qw(channel preorder_status preorder_item_status currency)
    );

with 'XT::DC::Messaging::Role::Producer',
    'XTracker::Role::WithIWSRolloutPhase',
    'XTracker::Role::WithSchema';

sub message_spec {
    return {
        type => '//rec',
        required => {
            channel => '/nap/channel',
            update_reason => '//str',
            customer_number => '//str',
            preorder_number => '//str',
            status => '/nap/preorder_status',
            delivery_info => '//str',
            currency => '/nap/currency',
            total_value => '//num',
            created => '/nap/datetime',
            items => {
                type => '//arr',
                contents => {
                    type => '//rec',
                    required => {
                        description => '//str',
                        sku => '/nap/sku',
                        colour => '//str',
                        size => '//str',
                        status => '/nap/preorder_item_status',
                        price => '//num',
                        tax => '//num',
                        duty => '//num',
                        item_total => '//num',
                    },
                    optional => {
                        comment => '//str',
                        order_number => '//str',
                    }
                }
            },
            payment => {
                type => '//rec',
                required => {
                    preauth_reference => '//str',
                    psp_reference     => '//str',
                }
            },
        },
        optional => {
            updated => '/nap/datetime',
            comment => '//str'
        },
    };
}

has '+type' => ( default => 'PreOrderUpdate' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my ($self, $header, $data) = @_;

    my $preorder = delete $data->{preorder};

    die "Need a pre-order, but didn't get one" unless $preorder;

    my $channel = $preorder->channel->web_name;

    # if the config does not map the destination, we don't have to send anything
    return unless $self->routes_map->{$channel};

    $header->{destination} = $channel;

    unless ( $data->{update_reason} ) {
        $data->{update_reason} = 'updated';
    }

    $data->{channel}         = $preorder->channel->web_name;
    $data->{customer_number} = $preorder->customer->is_customer_number;
    $data->{preorder_number} = $preorder->pre_order_number;

    # FCW -- can we come up with a better default than this?
    #        where can we get the delivery info from?
    #        is it even required, other than in the user story?

    $data->{delivery_info} = '';

    $data->{status}      = $preorder->pre_order_status->status;
    $data->{currency}    = $preorder->currency->currency;
    $data->{total_value} = $preorder->total_uncancelled_value;

    $data->{created} = as_zulu( $preorder->created );

    # presumes that, if we're sending a message to the web app, it's
    # because something has *just* changed
    $data->{updated} = as_zulu( DateTime->now );

    if ( $preorder->has_shipment_address_change ) {
        # this is a place-holder for any additional information
        # we think it's going to be useful to present to the customer,
        # but haven't thought of yet

        $data->{comment} = "There are special delivery instructions for this pre-order." ;
    }
    else {
        delete $data->{comment} if exists $data->{comment};
    }

    if ( $preorder->has_discount ) {
        my $discount = $preorder->applied_discount_percent;
        $data->{comment} //= '';        # if not already a string, make it a string
        $data->{comment}  .= " This Pre-Order has a ${discount}% discount applied.";
        $data->{comment}  =~ s/^ //;    # get rid of leading space if this is the only comment
    }

    $data->{items} = () ;

    foreach my $item ( $preorder->pre_order_items->order_by_id->all ) {
        my $itemdata = {} ;

        $itemdata->{status}      = $item->pre_order_item_status->status;
        $itemdata->{price}       = $item->unit_price;
        $itemdata->{tax}         = $item->tax;
        $itemdata->{duty}        = $item->duty;

        $itemdata->{item_total} = $itemdata->{price} +
                                  $itemdata->{tax} +
                                  $itemdata->{duty} ;

        if ( 0 ) {
            # this is really a place-holder for things like
            # 'Delivery expected in September'

            $itemdata->{comment} = 'Delivery expected in September' ;
        }

        if ( $item->is_exported ) {
            my $order = $item->order;

            # don't presume we do have an order yet, as it may not
            # have come in via the Order Importer

            $itemdata->{order_number} = $order->order_nr  if $order;
        }

        my $variant = $item->variant;

        $itemdata->{sku}         = $variant->sku;
        $itemdata->{size}        = $variant->designer_size->size;

        my $product = $variant->product;

        $itemdata->{colour}      = $product->colour->colour;
        $itemdata->{description} = $product->preorder_name;

        push @{$data->{items}},$itemdata;
    }

    my $payment = $preorder->pre_order_payment;

    $data->{payment}{preauth_reference} = $payment->preauth_ref;
    $data->{payment}{psp_reference}     = $payment->psp_ref;

    return ($header, $data);
}

1;
__END__
