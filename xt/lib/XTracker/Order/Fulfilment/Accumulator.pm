package XTracker::Order::Fulfilment::Accumulator;
use NAP::policy "tt";

# This page exists solely to allow a user to scan a bunch of totes to send
# to PrePackShipment.pm

use List::MoreUtils qw/ part /;

use NAP::DC::Barcode::Container;
use XTracker::Handler;
use XTracker::Error;
use XTracker::Navigation qw( build_packing_nav );

sub handler {
    my $handler = XTracker::Handler->new( shift );

    try   { _handler( $handler ) }
    catch { xt_warn($_)          };

    return $handler->process_template;
}

sub _handler {
    my $handler = shift;
    navigation_irritants( $handler );

    # Set the template
    $handler->{'data'}{'content'} = 'ordertracker/fulfilment/accumulator.tt';

    my $template_data = {};

    # These things we need, and it'd be weird if we didn't have them
    for my $param ( qw/shipment_id container_id/ ) {
        $template_data->{ $param } = $handler->{'param_of'}{ $param };
        unless ( defined( $template_data->{ $param } ) ) {
            die("You must provide a $param\n");
        }
    }

    # Setup the primary tote
    my $container_id = NAP::DC::Barcode::Container->new_from_id(
        $template_data->{'container_id'},
    );
    $template_data->{'primary'} = {
        id   => $container_id,
        type => typename( $container_id ),
    };

    # The 'outstanding' containers are ones that we still require, and
    # 'scanned' are the ones - other than the primary one - that we've already
    # scanned.
    for my $type ( qw/outstanding scanned/ ) {
        $template_data->{ $type } = [
            map {
                my $container_id = NAP::DC::Barcode::Container->new_from_id($_);
                +{
                    id   => $container_id,
                    type => typename( $container_id ),
                }
            } $handler->param_as_list( $type )
        ];
    }

    $template_data->{shipment_row} =
        $handler
            ->schema
            ->resultset('Public::Shipment')
            ->find($handler->{param_of}->{shipment_id});

    # Save this somewhere it'll be found
    $handler->{'data'}{'accumulator'} = $template_data;
}

sub typename {
    my ($container_id) = @_;

    # TODO: determine whether this should just use the
    # $container_id->name instead. Is this exact value used for anything?
    # If not, replace with ->name.
    return $container_id->is_type("pigeon_hole") ? 'Pigeonhole' : 'Tote';
}

# These are unlikely to add to your comprehension of this handler so I hid them.
# These have been mostly cargo-culted from PrePackShipment.pm
sub navigation_irritants {
    my $handler = shift;

    $handler->{data}{section} = 'Fulfilment';
    $handler->{data}{subsection} = 'Packing';
    $handler->{data}{subsubsection} = 'Collate Containers';

    # back link in left nav
    push( @{ $handler->{data}{sidenav}[0]{'None'} },
        { 'title' => 'Back', 'url' => "/Fulfilment/Packing" } );

    # check for 'Set Packing Station' link
    my $sidenav = build_packing_nav( $handler->{schema} );
    if ( $sidenav ) {
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, $sidenav );
    }

    return;
}

1;
