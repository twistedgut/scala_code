package XTracker::Order::Fulfilment::Commissioner;

use warnings;
use strict;
use Try::Tiny;

use Perl6::Export::Attrs;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Handler;
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    try {
        display_commissioner_page($handler);
    }
    catch {
        xt_die("Unexpected error: $_");
    };

    return OK;
}

sub display_commissioner_page : Export() {
    my ($handler) = @_;
    my $schema  = $handler->{schema};

    $handler->{data}{section}    = 'Fulfilment';
    $handler->{data}{subsection} = 'Commissioner';
    $handler->{data}{content}    = 'ordertracker/fulfilment/commissioner.tt';

    my @cancel_pending;
    my @shipment_on_hold;
    my @ready_for_packing;
    my @awaiting_collection;

    my $commissioner_containers = $schema->resultset('Public::Container')->in_commissioner;

    while (my $container = $commissioner_containers->next) {
        if ($container->are_all_shipments_cancelled) {
            push @cancel_pending, $container;
        }
        elsif ($container->are_all_shipments_on_hold) {
            push @shipment_on_hold, $container;
        }
        elsif ($container->packing_ready_in_commissioner) {
            push @ready_for_packing, $container;
        }
        else {
            push @awaiting_collection, $container;
        }
    }

    $handler->{data}{cancel_pending} = \@cancel_pending;
    $handler->{data}{shipment_on_hold} = \@shipment_on_hold;
    $handler->{data}{ready_for_packing} = \@ready_for_packing;
    $handler->{data}{awaiting_collection} = \@awaiting_collection;

    $handler->process_template( undef );

    return OK;
}

1;
