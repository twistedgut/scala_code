package Test::XTracker::Carrier;

use Moose;

# HEY YOU! Do you know what this module does? Did you write portions of it?
# Be a hero, today, and add some documentation: http://jira4.nap/browse/CLIVE-97

use XTracker::Database qw< get_database_handle>;
use XTracker::Constants::FromDB qw/
    :shipment_type
    :manifest_status
    :shipment_status
    :shipment_item_status
    :shipping_charge_class
/;
use XTracker::Constants qw/
    :application
/;
use XTracker::Database::Shipment qw( :DEFAULT get_shipment_shipping_account );
use XTracker::DHL::Manifest qw( generate_manifest_files update_manifest_status );
use Test::XTracker::Data;
use DateTime;

with 'XTracker::Role::WithSchema';

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);


sub _create_shipment {
    my ($self,$args) = @_;

    $args->{boxes} ||= 1;
    # if we haven't been given a specific carrier name, use "DHL
    # Express" (DHL Ground is no longer used)
    $args->{carrier_name} ||= 'DHL Express';
    $args->{shipment_type} ||= $SHIPMENT_TYPE__DOMESTIC;


    my @carriers = $self->schema->resultset('Public::Carrier')
        ->search({
            name => { -ilike => $args->{carrier_name} },
        })->all;

    $args->{channel_id} ||= Test::XTracker::Data->channel_for_nap()->id();

    my $account = $self->schema->resultset('Public::ShippingAccount')->search({
        ( defined $args->{channel_id}
              ? ( channel_id => $args->{channel_id} )
              : ()
          ),
        carrier_id => [map {$_->id} @carriers]
    })->slice(0,0)->single;

    return (undef,undef,undef)
        unless $account;

    my $carrier = $account->carrier;

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => $args->{boxes},
        channel_id => $args->{channel_id},
    });
    my ($order)=Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => {
            channel_id => $args->{channel_id},
        },
    });

    my $shipment = $order->shipments->first;

    my $box_ids = Test::XTracker::Data->get_inner_outer_box($args->{channel_id});

    my @box_objs = map {
        $shipment->add_to_shipment_boxes({
            box_id => $box_ids->{outer_box_id},
            inner_box_id => $box_ids->{inner_box_id},
        })
    } 1..$args->{boxes};

    $shipment->update_status($SHIPMENT_STATUS__PROCESSING,$APPLICATION_OPERATOR_ID);

    my $pos=0;
    for my $item ($shipment->shipment_items->all) {
        $item->update_status($SHIPMENT_ITEM_STATUS__PACKED,$APPLICATION_OPERATOR_ID);
        $item->update({shipment_box_id => $box_objs[$pos]->id});
        ++$pos;
    }

    my $dt = DateTime->now( time_zone => "local" )->add(minutes => 2);
    my $cutoff = $dt->year."-".$dt->month."-".$dt->day." ".$dt->hour.":".$dt->minute;

    my %extra;
    if ($carrier->name eq 'UPS') {
        $extra{outward_airway_bill} = 'none';
        $extra{return_airway_bill} = 'none';
        $extra{destination_code} = undef;
    }
    elsif ($carrier->name eq 'DHL Express') {
        $extra{outward_airway_bill} = '123';
        $extra{return_airway_bill} = '456';
    }

    # Find a valid shipping_charge object
    my $charge_class = $self->schema->resultset('Public::ShippingCharge')->search({
        channel_id  => $args->{channel_id},
        id          => { '>' => 0 }, # Want to avoid the slighty dodgy 'Unknown' object
        class_id    => ($args->{shipment_type} == $SHIPMENT_TYPE__PREMIER
            ? $SHIPPING_CHARGE_CLASS__SAME_DAY
            : { '!=' => $SHIPPING_CHARGE_CLASS__SAME_DAY }
        ),
    }, {
        rows => 1,
    })->first;

    $shipment->update({
        shipment_type_id => $args->{shipment_type},
        shipping_account_id => $account->id,
        date => DateTime->now(time_zone => "local"),
        sla_cutoff => $dt,
        real_time_carrier_booking => 0,
        shipping_charge_id  => $charge_class->id(),
        %extra,
    });

    if ($carrier->name ne 'Unknown') {
        # filename for our export text file and PDF
        my $filename = $carrier->id . "_manifest_" . $dt->year."_".$dt->month."_".$dt->day."_".$dt->hour."_".$dt->minute."_".$dt->second;

        my $schema = $self->schema;
        my $dbh = $schema->storage->dbh;
        my $manifest_id = $schema->resultset('Public::Manifest')->create_manifest({
            carrier_id => $carrier->id,
            filename => $filename,
            cut_off => $dt
        }, {
            channel_ids => [$schema->resultset('Public::Channel')->get_column('id')->all()]
        })->id();

        generate_manifest_files( $schema, {
            manifest_id => $manifest_id,
            carrier_id => $carrier->id,
            filename => $filename,
            cut_off => $cutoff,
        });

        update_manifest_status($dbh,
                               $manifest_id,
                               "Exported",
                               $APPLICATION_OPERATOR_ID,
                           );

        # link the manifest to the shipment if
        # the machines date & time is a bit out
        if ( !defined $shipment->manifests->first ) {
            $shipment->create_related( 'link_manifest__shipments', { manifest_id => $manifest_id } );
        }
    }

    my $manifest = $shipment->manifests->first;

    return ($order,$shipment,$manifest);
}

sub any_manifest {
    my $self = shift;

    return $self->ups_manifest() || $self->dhl_manifest();
}

sub dhl_manifest {
    my $self = shift;

    my ($order,$shipment,$manifest)=$self->_create_shipment({
        carrier_name => shift,
    });

    return $manifest;
}

sub ups_manifest {
    my $self = shift;

    my ($order,$shipment,$manifest)=$self->_create_shipment({
        carrier_name => 'UPS',
    });
    return $manifest;
}

sub unknown_shipment {
    my $self = shift;

    my ($order,$shipment,$manifest)=$self->_create_shipment({
        carrier_name => 'Unknown',
    });

    return $shipment;
}

sub premier_shipment {
    my $self = shift;

    my ($order,$shipment,$manifest)=$self->_create_shipment({
        shipment_type => $SHIPMENT_TYPE__PREMIER,
        carrier_name => 'Unknown',
    });

    return $shipment;
}

sub ups_shipment {
    my $self = shift;

    my ($order,$shipment,$manifest)=$self->_create_shipment({
        carrier_name    => 'UPS',
    });

    return $shipment;
}

sub ups_shipment_by_channel {
    my $self    = shift;
    my $ch_id   = shift;

    my ($order,$shipment,$manifest)=$self->_create_shipment({
        carrier_name => 'UPS',
        channel_id => $ch_id,
    });

    return $shipment;
}

# gets a UPS shipment which has at least 2 shipment boxes
sub ups_shipment_multi_box {
    my $self = shift;

    my ($order,$shipment,$manifest)=$self->_create_shipment({
        carrier_name => 'UPS',
        boxes => 2,
    });

    return $shipment;
}

sub dhl_shipment {
    my $self = shift;

    my ($order,$shipment,$manifest)=$self->_create_shipment({
        carrier_name => shift,
    });

    return $shipment;
}

1;
