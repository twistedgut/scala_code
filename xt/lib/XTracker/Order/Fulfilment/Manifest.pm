package XTracker::Order::Fulfilment::Manifest;

use strict;
use warnings;

use DateTime;
use DateTime::Format::Strptime;
use Try::Tiny;

use XTracker::Handler;
use XTracker::DHL::Manifest qw( get_manifest get_manifest_status_log get_manifest_shipment_list get_working_manifest_list get_manifest_list );

use NAP::Carrier;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    $handler->{data}{section}    = 'Fulfilment';
    $handler->{data}{subsection} = 'Manifest';
    $handler->{data}{content}    = 'ordertracker/fulfilment/manifest.tt';
    $handler->{data}{now}        = $schema->db_now;
    $handler->{data}{tomorrow}   = $handler->{data}{now}->clone->add(days => 1);

    $handler->add_to_data({
        channels => [$schema->resultset('Public::Channel')->enabled_channels->all],
        # filter_active is redundant here, but keeping so we don't display
        # carriers that use the manifest but are 'dormant'
        carriers => [
            $schema->resultset('Public::Carrier')
                ->filter_with_manifest
                ->filter_active
                ->order_by('id')
                ->all
        ],
    });

    # manifest id in URL - get list of shipments in manifest
    if ( my $manifest_id = $handler->{param_of}{mid} ){
        $handler->{data}{view}     = 'shipment';
        $handler->{data}{manifest} = get_manifest( $dbh, $manifest_id );
        $handler->{data}{log}      = get_manifest_status_log( $dbh, $manifest_id );
        $handler->{data}{list}     = get_manifest_shipment_list( $dbh, $manifest_id );

        my $nc = NAP::Carrier->new({
            schema      => $schema,
            manifest_id => $manifest_id,
            operator_id => $handler->operator_id,
        });
        push(
            @{ $handler->{data}{sidenav}[0]{'None'} },
            { 'title' => 'Back',            'url' => "/Fulfilment/Manifest" },
            { 'title' => 'View Text File',  'url' => $nc->manifest_txt_link },
            { 'title' => 'View PDF',        'url' => $nc->manifest_pdf_link }
        );

        return $handler->process_template;
    }

    # else we're displaying the manifest overview page
    $handler->{data}{view} = 'manifest';

    # we always display the list of working manifests
    $handler->{data}{working} = get_working_manifest_list( $dbh );

    # ... just a few more steps if we've done a search
    return $handler->process_template unless $handler->{param_of}{search};

    # manifest search by shipment
    if ( my $shipment_id = $handler->{param_of}{shipment_id} ) {
        $handler->{data}{search} = get_manifest_list( $dbh, {
            type        => 'shipment',
            shipment_id => $shipment_id,
        });
    }
    # manifest search by date
    else {
        my %date = (
            start => $handler->{param_of}{from_date},
            end   => $handler->{param_of}{to_date},
        );
        try {
            my $time_zone = $handler->get_config(qw/DistributionCentre timezone/);
            to_date($_, $time_zone) for values %date;
            $handler->{data}{search} = get_manifest_list($dbh, {
                type => 'date',
                %date
            });
        }
        catch {
            $handler->xt_warn($_);
        };
    }

    return $handler->process_template;
}

=head2 to_date($date_str, $time_zone) : $datetime_object

Transform into a L<DateTime> object. This will die unless you pass a valid
string.

=cut

sub to_date {
    my ($date_str, $time_zone) = @_;

    my $strp = DateTime::Format::Strptime->new(
        pattern   => '%F',
        time_zone => $time_zone,
    );
    return $strp->parse_datetime($date_str)
        || die sprintf "Invalid date '$date_str': %s\n", $strp->errmsg;
}

1;
