package XTracker::Order::Actions::RemoveRoutingExportShipment;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Database::Routing qw( remove_routing_export_shipment );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $routing_export_id = $handler->{param_of}{'routing_export_id'};
    eval {
        my $schema = $handler->schema;
        $schema->txn_do(sub{
            my $dbh = $schema->storage->dbh;
            foreach my $key ( keys %{$handler->{param_of}} ) {
                my ($action, $shipment_id) = split /_/, $key;

                if ( $action eq 'remove' && defined($shipment_id) ) {
                    remove_routing_export_shipment(
                        $dbh, $routing_export_id, $shipment_id
                    );
                }
            }
        });
    };
    if ($@) {
        xt_warn($@);
        return OK;
    }
    return $handler->redirect_to("Fulfilment/PremierRouting?routing_export_id=$routing_export_id" );
}

1;
