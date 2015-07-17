package XTracker::Order::Actions::ExportRoutingFile;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Handler;
use XTracker::Database::Routing qw( create_routing_export generate_routing_export_file update_routing_export_status check_routing_export_lock );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $channel_id  = $handler->{request}->param('channel_id');
    my $operator_id = $handler->operator_id;

    my $schema  = $handler->schema;
    my $dbh     = $schema->storage->dbh;

    my $channel = $schema->resultset('Public::Channel')->get_channel($channel_id);
    my $business_type = $channel->{config_section};

    my $cutoff = $handler->{request}->param('year')
        ."-".$handler->{request}->param('month')
        ."-".$handler->{request}->param('day')
        ." ".$handler->{request}->param('hour')
        .":".$handler->{request}->param('minute')
        .":59"; # the query will do <= so we need to include up to the end of this minute

    my $redirect_url = '/Fulfilment/PremierRouting';
    ### check to make sure another manifest isn't being created at the same time
    if (check_routing_export_lock($dbh)){
        xt_warn("Routing File already exporting");
        return $handler->redirect_to($redirect_url);
    }

    ### generate filename with current timestamp
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    $mon++;
    $year = $year + 1900;

    my $filename = "routing_${business_type}_".$year."_".$mon."_".$mday."_".$hour."_".$min."_".$sec;

    my $export_id;
    ### create manifest record in the database
    eval {
        $schema->txn_do(sub{
            $export_id = create_routing_export($dbh, $filename, $cutoff, $operator_id, $channel_id);
        });
    };
    if ( $@ ) {
        xt_warn( "Could not create export record in DB: $@" );
        return $handler->redirect_to($redirect_url);
    }
    ### export the manifest file
    eval {
        $schema->txn_do(sub{
            my $fullpath = generate_routing_export_file($schema, $export_id, $filename, $cutoff, $channel_id);
            die "$fullpath doesnt exists" unless $fullpath && -f $fullpath;
            ### finished - log routing export as being "Exported"
            update_routing_export_status($dbh, $export_id, "Exported", $operator_id);
        });
    };

    ### export failed
    if ($@) {
        ### log routing export as being "Cancelled"
        update_routing_export_status($dbh, $export_id, "Cancelled", $operator_id);
        xt_warn( "Export Failed: $@" );
    }

    # return to main page. do not drill into specific export page
    return $handler->redirect_to( '/Fulfilment/PremierRouting' );
}

1;
