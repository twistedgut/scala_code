#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use FindBin::libs qw( base=lib_dynamic );

use Carp;
use Encode qw/encode decode/;

use XTracker::Database qw( :common );
use XTracker::Database::Currency;
use XTracker::Database::PurchaseOrder qw(:create);

# set up db handle
my $dbh         = get_database_handle( {name => 'xtracker', type => 'readonly'} );
my $dbh_tr_dc1  = get_database_handle( {name => 'xtracker', type => 'transaction'} );

# Create a number of purchase orders.
# These values can differ between Purchase Orders
my $po_data = [{
    description     => 'USA',
    designer        => 'Christian Louboutin',
    supplier        => 'ALC',
    },{
    description     => 'GB',
    designer        => 'Ali Ro',
    supplier        => 'American Retro',
    },{
    description     => 'Italy',
    designer        => 'Amici',
    supplier        => 'Anio Ltd',
    },
];
# Fixed data, the same for every Purchase Order we create
my $po_fixed = {
    channel         => 'NET-A-PORTER.COM',
    status          => 'On Order',
    comment         => '',
    currency        => 'GBP',
    exchange_rate   => 0.68,
    season          => 'CR11',
    type            => 'First Order',
    act             => 'Main',
    placed_by       => 'Ian Docherty',
};

my $channel_id      = get_channel_id($dbh, $po_fixed->{channel});
my $currency_id     = get_currency_id($dbh, $po_fixed->{currency});
my $act_id          = get_act_id($dbh, $po_fixed->{act});
my $season_id       = get_season_id($dbh, $po_fixed->{season});
my $po_type_id      = get_purchase_order_type_id($dbh, $po_fixed->{type});
my $po_status_id    = get_purchase_order_status_id($dbh, $po_fixed->{status});


# use the epoch time to create an initial value for the PO Number
# NOTE: Using the time is not guaranteed to produce a unique number, ideally
# use the 'purchase_order_id_seq' but we can't use this either whilst we produce
# SQL which is applied to the database at a later time.
# Not a big problem since I don't anticipate this script being used for long.
#
my $po_nr = time;

my $output = <<END_BEGIN;
--
-- Create a number of Purchase Orders for test purposes in the $po_fixed->{channel} channel
--
-- start transaction
BEGIN;
END_BEGIN

for my $po (@$po_data) {
    #print "Adding Purchase Order: description [$po->{description}] designer [$po->{designer}] supplier [$po->{supplier}\n";
    my $supplier_id = get_supplier_id($dbh, $po->{supplier});
    my $designer_id = get_designer_id($dbh, $po->{designer});

    # Create a unique(ish) PO Number
    #print "PO Number = [NAP_TEST_$po_nr]\n";
    $po_nr++;

    $output .= <<END_INSERT;
    --
    INSERT INTO purchase_order (id, date, purchase_order_number, description, designer_id, status_id, comment, currency_id, exchange_rate, season_id, type_id, cancel, supplier_id, act_id, confirmed, placed_by, channel_id )
        VALUES (default, current_timestamp, 'NAP_TEST_$po_nr', '$po->{description}', $designer_id, $po_status_id, '$po_fixed->{comment}', $currency_id, $po_fixed->{exchange_rate}, $season_id, $po_type_id, '0', $supplier_id, $act_id, '0', '$po_fixed->{placed_by}', $channel_id );
END_INSERT
}

$output .= <<END_COMMIT;
--
-- end transaction
COMMIT;
END_COMMIT

print $output;

# Get the channel ID given the channel NAME
#
sub get_channel_id {
    my ( $dbh, $name ) = @_;

    my $query = 'SELECT id FROM channel WHERE name = ?';
    my $sth = $dbh->prepare($query);
    $sth->execute($name);
    my $data = $sth->fetchrow_hashref();

    if (! $data) {
        croak("Cannot find channel ID for name '$name'\n");
    }
    return $data->{id};
}

# Get the supplier ID given the supplier NAME
#
sub get_supplier_id {
    my ( $dbh, $name ) = @_;

    my $query = 'SELECT id FROM supplier WHERE description = ?';
    my $sth = $dbh->prepare($query);
    $sth->execute($name);
    my $data = $sth->fetchrow_hashref();

    if (! $data) {
        croak("Cannot find supplier ID for name '$name'\n");
    }
    return $data->{id};
}

# Get the designer ID based on the designers name
#
sub get_designer_id {
    my ( $dbh, $designer ) = @_;

    $designer = encode("utf-8", $designer);

    my $query = 'SELECT id FROM designer WHERE lower(designer) = lower(?)';
    my $sth = $dbh->prepare($query);
    $sth->execute( $designer );
    my $data = $sth->fetchrow_hashref();

    if (! $data) {
        croak("Cannot find designer ID for name '$designer'\n");
    }
    return $data->{id};
}

# Get the Season Act ID based on the act name
#
sub get_act_id {
    my ( $dbh, $act ) = @_;

    my $query = 'SELECT id FROM season_act WHERE lower(act) = lower(?)';
    my $sth = $dbh->prepare($query);
    $sth->execute( $act );

    my $data = $sth->fetchrow_hashref();

    if (! $data) {
        croak("Cannot find Season Act ID for name '$act'\n");
    }
    return $data->{id};
}

# Get the Season ID based on the Season Name
#
sub get_season_id {
    my ( $dbh, $season ) = @_;

    my $query = 'SELECT id FROM season WHERE season = ?';
    my $sth = $dbh->prepare($query);
    $sth->execute( $season );

    my $data = $sth->fetchrow_hashref();

    if (! $data) {
        croak("Cannot find Season ID for name '$season'\n");
    }
    return $data->{id};
}

# Get the PO Type based on the Type Name
#
sub get_purchase_order_type_id {
    my ( $dbh, $type ) = @_;

    my $query = 'SELECT id FROM purchase_order_type WHERE type = ?';
    my $sth = $dbh->prepare($query);
    $sth->execute( $type  );

    my $data = $sth->fetchrow_hashref();

    if (! $data) {
        croak("Cannot find PO Type ID for type '$type'\n");
    }
    return $data->{id};
}

# Get the PO Status ID based on the Status Name
#
sub get_purchase_order_status_id {
    my ( $dbh, $status ) = @_;

    my $query = 'SELECT id FROM purchase_order_status WHERE status = ?';
    my $sth = $dbh->prepare($query);
    $sth->execute( $status );

    my $data = $sth->fetchrow_hashref();

    if (! $data) {
        croak("Cannot find PO Status ID for name '$status'\n");
    }
    return $data->{id};
}

1;
