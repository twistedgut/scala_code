#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

selection.t - Test the selection process and picksheet printing for samples

=head1 DESCRIPTION

Test the selection process and picksheet printing for samples when
they're being picked manually in XT.

#TAGS sample fulfilment selection picksheet printer picking phase0 whm

=head1 METHODS

=cut

use FindBin::libs;

use Test::XTracker::RunCondition iws_phase => 0, prl_phase => 0;

use utf8;

use Test::XTracker::Data;

use Test::XTracker::Mechanize;
use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::RAVNI;
use Data::Dump  qw( pp );

my $mech    = Test::XTracker::Mechanize->new;
my $schema  = $mech->schema;
# change channel selection to not select 'Mr Porter'
# FIXME: Not testing MRP
my @channels = $schema->resultset('Public::Channel')->search(
    { 'is_enabled' => 1, name => { '!=' => 'MRPORTER.COM' } },
    { order_by => 'id' }
)->all;

__PACKAGE__->_setup_user_perms;
Test::XTracker::Data->set_department('it.god', 'Sample');

$mech->do_login;

foreach my $channel ( @channels ) {
    note "Testing Sample Selection for Channel: ".$channel->id." - ".$channel->name;

    Test::XTracker::Data->set_department('it.god', 'Sample');

    my $pids    = Test::XTracker::Data->find_products({
        channel_id => $channel->id,
        dont_ensure_live_or_visible => 1,
    });
    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    $mech->test_create_sample_request( $pids );
    Test::XTracker::Data->set_department('it.god', 'Stock Control');
    $mech->test_approve_sample_request( $pids );

    Test::XTracker::Data->set_department('it.god', 'Shipping');
    test_sample_selection( $mech, $pids, $channel, 1 );
}

done_testing;


=head2 test_sample_selection

    $mech  = test_sample_selection( $mech, $pids, $channel, $oktodo )

This will test the selection process for Sample Stock Transfer requests and that they print to the correct printer and not the usual printers for normal shipments.

=cut

sub test_sample_selection {
    my ( $mech, $pids, $channel, $oktodo )  = @_;

    my $shipment_id = $pids->[0]{shipment_id};
    my $shipment    = $schema->resultset('Public::Shipment')->find( $shipment_id );

    SKIP: {
        skip "test_sample_selection",1         if ( !$oktodo );

        note "TESTING Sample Stock Request Selection - Regular";

        my $print_directory = Test::XTracker::PrintDocs->new();
        my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

        # print using normal printer should go to 'Goods In' printer
        $mech->get_ok( '/Fulfilment/Selection?selection=transfer');
        $mech->submit_form_ok( {
            form_name   => 'f_select_shipment',
            fields => {
                'pick-'.$shipment_id    => 1,
            },
            button      => 'submit',
        }, "Make Selection: ".$shipment_id );
        $mech->no_feedback_error_ok;

        $xt_to_wms->wait_for_new_files();
        my ($picking_sheet) = grep {
            $_->file_type eq 'pickinglist'
        } $print_directory->new_files();
        die "No picking sheet found" unless $picking_sheet;
    };

    return $mech;
}


#---------------------------------------------------------------------------------

sub _setup_user_perms {
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 3);
    # Perms needed for the Fulfilment process
    for (qw/Selection/ ) {
        Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 3);
    }
    # Perms needed for the Stoc Control process
    for (qw/Inventory Sample/ ) {
        Test::XTracker::Data->grant_permissions('it.god', 'Stock Control', $_, 3);
    }
}
