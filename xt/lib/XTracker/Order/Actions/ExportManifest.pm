package XTracker::Order::Actions::ExportManifest;
use strict;
use warnings;

use DateTime;
use DateTime::Format::Strptime;
use XTracker::Handler;
use XTracker::DHL::Manifest qw( generate_manifest_files update_manifest_status );
use XTracker::Error;
use Try::Tiny;

use XTracker::Constants::FromDB qw(
    :manifest_status
);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema = $handler->schema;
    my $redirect = '/Fulfilment/Manifest';
    try {

        die qq{At least one channel must be selected to export a new manifest.\n}
            unless defined($handler->{param_of}{channel_id});

        my $channel_ids = ( ref($handler->{param_of}{channel_id}) eq 'ARRAY'
            ? $handler->{param_of}{channel_id}
            : [$handler->{param_of}{channel_id}]
        );

        # check if manifest already in process of being sent
        my $carrier_id = $handler->{param_of}{carrier_id};
        my $carrier = $schema->resultset('Public::Carrier')->find($carrier_id);
        if (my $manifest = $carrier->get_locking_manifest_rs($channel_ids)->first() ) {
            die sprintf(
                qq{A <a href="%s">manifest</a> is already being exported, please complete it or cancel it before exporting a new one.\n},
                $redirect . '?mid=' . $manifest->id
            );
        }

        # Transform into datetime object for validation
        my $strp = DateTime::Format::Strptime->new(
            pattern   => '%F %R',
            time_zone => $handler->get_config(qw/DistributionCentre timezone/),
        );
        my $cutoff_str
            = $handler->{param_of}{cutoff_date}
            . q{ }
            . join( q{:}, @{$handler->{param_of}}{qw/cutoff_hour cutoff_minute/} );
        my $cutoff_dt = $strp->parse_datetime($cutoff_str)
            or die sprintf "Invalid date '$cutoff_str': %s\n", $strp->errmsg;

        # Filename for our export text file and PDF. Note that this is returned
        # to us in 'local' timezone
        my $dt = $schema->db_now;
        my $filename = join q{_},
            $carrier_id, 'manifest', map { $dt->$_ } (qw<year month day hour minute second>);

        my $guard = $schema->txn_scope_guard;
        # create the manifest
        my $manifest = $schema->resultset('Public::Manifest')->create_manifest({
            carrier_id  => $carrier_id,
            filename    => $filename,
            cut_off     => $cutoff_dt,
        }, {
            channel_ids => $channel_ids,
        });

        # generate the manifest files
        generate_manifest_files( $schema, {
            carrier_id  => $carrier_id,
            channel_ids => $channel_ids,
            filename    => $filename,
            cut_off     => $cutoff_dt->strftime('%F %R'),
            manifest_id => $manifest->id,
        });

        $manifest->update_status($PUBLIC_MANIFEST_STATUS__EXPORTED);

        $guard->commit;
        xt_success('Manifest exported successfully');
        $redirect .= "?mid=" . $manifest->id;
    } catch {
        xt_warn("An error occured whilst trying to export the manifest: <br />$_");
    };
    return $handler->redirect_to( $redirect );
}

1;
