package Test::NAP::StockControl::Location;

=head1 NAME

Test::NAP::StockControl::Location - This tests the location functions in stock control

=head1 DESCRIPTION

This tests the location functions in stock control.

#TAGS inventory iws prl printer checkruncondition

=head1 METHODS

=cut


use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::PrintDocs;
use XTracker::Database::Location 'generate_location_list';
use XTracker::Utilities qw(get_start_end_location);
use XTracker::Constants::FromDB qw( :authorisation_level );

use Test::XTracker::RunCondition export => [qw($iws_rollout_phase $prl_rollout_phase)];

use parent 'NAP::Test::Class';

sub startup : Test(startup => 1) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(traits =>
        [ 'Test::XT::Data::Location', 'Test::XT::Flow::StockControl::Location' ]);
    $self->{framework}->mech->do_login;
}

sub setup : Test(setup) {
    my ( $self ) = @_;

    $self->SUPER::setup;

    Test::XTracker::Data->grant_permissions('it.god', 'Stock Control', 'Location',
        $AUTHORISATION_LEVEL__MANAGER );
}

=head2 test_printing_barcodes

This test goes to the print location barcodes page and prints a range of barcodes.
It ensures that:

    a) we don't print barcodes for non-existent locations (if we are not in DC1)
    b) the correct barcodes are printed.

=cut

sub test_printing_barcodes : Tests {
    my ( $self ) = @_;

    my $framework = $self->{framework};
    my $mech = $framework->mech;

    # Go to the page for printing barcodes
    $framework->flow_mech__stockcontrol__location__print_locations_form;

    # Generate range of 4 locations to print. In IWS and PRL phases we expect
    # all to print since we don't care if they exist in XT. Elsewhere we expect
    # just the first 2, since the range includes 2 locations that exist and 2
    # that don't.
    my $range_specs = {
        start_floor => '1',
        start_zone => 'A',
        start_location => '0001',
        start_level => 'A',
        end_floor => '1',
        end_zone => 'B',
        end_location => '0001',
        end_level => 'B'};
    my ($start, $end) = get_start_end_location($range_specs);
    my @generated_locations = generate_location_list($start, $end);
    my @expected_locations
        = $iws_rollout_phase == 0 && $prl_rollout_phase == 0
        ? @generated_locations[0..1]
        : @generated_locations;
    my @expected_filenames = map {"location-$_.lbl"} @expected_locations;

    # In DC2 we need to ensure locations are populated in the DB.
    $framework->data__location__initialise_non_iws_test_locations
        if $iws_rollout_phase == 0 && $prl_rollout_phase == 0;

    # Set up a print queue monitor
    my $print_directory = Test::XTracker::PrintDocs->new(filter_regex => undef);

    # Submit form to print range of barcodes
    my $printer_name = 'Goods In Barcode - Large';
    $framework->flow_mech__stockcontrol__location__submit_print_form($range_specs,$printer_name);

    # Check user feedback is correct
    for my $location ( @generated_locations ) {
        if ( $location ~~ \@expected_locations ) {
            $mech->has_feedback_info_ok(qr{Printing $location})
        }
        else {
            $mech->has_feedback_info_ok(qr{Skipping $location, does not exist});
        }
    }
    # Check if the expected files were printed
    my @found_files = $print_directory->wait_for_new_files( files => scalar(@expected_filenames) );
    my @found_filenames = sort ( map {$_->filename} @found_files );
    ok (@found_filenames ~~ @expected_filenames, 'Found expected print files');
}

1;
