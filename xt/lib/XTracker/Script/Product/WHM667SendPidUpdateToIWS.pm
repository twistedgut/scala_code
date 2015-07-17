package XTracker::Script::Product::WHM667SendPidUpdateToIWS;

use Moose;

use Time::HiRes 'sleep';
use Try::Tiny;

use XTracker::Constants::FromDB qw{:flow_status :shipment_class};

extends 'XTracker::Script';
with map { "XTracker::Script::Feature::$_" } (qw{Schema});
with 'XTracker::Role::WithAMQMessageFactory';

sub invoke {
    my ( $self, %args ) = @_;

    my $schema = $self->schema;
    my $verbose = !!$args{verbose};

    # This would require specifying joins in the definition of the DBIC class, and
    # I really can't be bothered doing that, so we will have two db calls

    # Get a rs of products that are live and have main stock
    my @live_products_with_stock = $schema->resultset('Public::Variant')->search(
        {
            'product_channel.live' => 1,
            'quantities.quantity' => { q{>} => 0 },
            'quantities.status_id' => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        },
        {
            join => [ 'quantities', { product => 'product_channel' } ],
            order_by => 'product.id',
        }
    )->search_related('product', undef, { columns => 'product.id', distinct => 1, })
    ->all;
    $verbose &&
        printf "Got %d live products with stock (including duplicates)\n",
            scalar @live_products_with_stock;

    # Create a hash of pids that have customer returns
    my %returned_pids = map {
        $_ => 1
    } $schema
        ->resultset('Public::ReturnItem')
        ->search(
            { 'shipment.shipment_class_id' => {
                -not_in => [
                    $SHIPMENT_CLASS__SAMPLE,
                    $SHIPMENT_CLASS__PRESS,
                    $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
                    $SHIPMENT_CLASS__RTV_SHIPMENT,
                ]
            },},
            { join => { return => 'shipment', }, }
        )->related_resultset('variant')
        ->get_column('product_id')
        ->func('distinct');
    $verbose && printf "Got %d products with customer returns\n",
        scalar keys %returned_pids;

    my ($sleep_length,$sleep_every) = split /\//,($args{throttle}//'0/100000');
    $sleep_length = 0 unless $sleep_length =~ m{^\d+$};
    $sleep_every = 100000 unless $sleep_every =~ m{^\d+$};

    my $amq = $self->msg_factory;
    my $count = 0;
    for my $product ( @live_products_with_stock ) {
        my $pid = $product->id;
        # We don't want to send messages for PIDs with returns
        next if $returned_pids{$pid};
        $verbose && print "Sending pid update message for $pid\n";
        try {
            $amq->transform_and_send('XT::DC::Messaging::Producer::WMS::PidUpdate', $product->discard_changes)
                unless $args{dryrun};
        }
        catch {
            warn "Couldn't send message for $pid: $_\n";
        };
        if (++$count % $sleep_every == 0) {
            printf "Sleeping $sleep_length second%s\n",
                $sleep_length == 1 ? q{} : q{s};
            sleep($sleep_length)
        }
    }

    $verbose && print "Sent $count messages to IWS\n",
                      "DONE!\n";
}

1;
