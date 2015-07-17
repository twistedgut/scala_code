package Test::NAP::RTV::PrintingViaQuarantine;

=head1 NAME

Test::NAP::RTV::PrintingViaQuarantine - Test printing Quarantine docs for RTV

=head1 DESCRIPTION

Test printing Quarantine docs for RTV

#TAGS inventory quarantine iws rtv printer

=head1 METHODS

=cut

use NAP::policy "tt", qw/test class/;

use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level :flow_status );
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var );
use Test::XTracker::PrintDocs;

BEGIN {
    extends "NAP::Test::Class";
    with
        'XTracker::Role::WithSchema',
        'XTracker::Role::WithPRLs',
        'XTracker::Role::WithIWSRolloutPhase',
        'Test::XT::Data::Quantity';
    with 'Test::XTracker::Data::Quarantine';

    has 'framework' => (
        is => 'ro',
        default => sub {
            my $framework = Test::XT::Flow->new_with_traits( traits => [qw/
                Test::XT::Data::Location
                Test::XT::Feature::LocationMigration
                Test::XT::Flow::GoodsIn
                Test::XT::Flow::RTV
                Test::XT::Flow::PrintStation
                Test::XT::Flow::StockControl::Quarantine
            /]);
        },
    );
};

sub test__print_quarantine_docs :Tests {
    my ($self) = @_;

    my $framework = $self->framework;
    $framework->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Goods In/Putaway',
                'Stock Control/Inventory',
                'Stock Control/Quarantine',
            ]
        }
    });

    note 'Clearing all test locations';
    $framework->data__location__destroy_test_locations;
    $framework->force_datalite(1);

    my $quantity = $self->get_pre_quarantine_quantity();

    my $variant_id = $quantity->variant->id();
    my $product = $quantity->product();
    my $location = $quantity->location();

    $framework->task__set_printer_station(qw/StockControl Quarantine/);
    $framework->flow_mech__stockcontrol__inventory_stockquarantine( $product->id() );

    my ($qnote, $quarantine_return) = $framework
        ->flow_mech__stockcontrol__inventory_stockquarantine_submit(
            variant_id => $variant_id,
            location   => $location->location(),
            type       =>  'L'
        );

    my $process_group_id = $quarantine_return;
    my $dir = config_var('SystemPaths', 'document_rtv_dir');

    my $print_directory = Test::XTracker::PrintDocs->new;
    $process_group_id = $framework
        ->flow_mech__stockcontrol__quarantine_processitem(
            $quarantine_return->id
        )->flow_mech__stockcontrol__quarantine_processitem_submit(
            rtv => 1
        );
    my @print_dir_new_file = $print_directory->wait_for_new_files( files => 1  );

    is( scalar( @print_dir_new_file ), 1, 'Correct number of files printed' );

    # first file should always be delivery
    is( $print_dir_new_file[0]->{file_type}, 'rtv', 'Correct file type' );
    is( $print_dir_new_file[0]->{printer_name}, 'rtv', 'Sent to the correct printer' );
    is( $print_dir_new_file[0]->{copies}, 1, 'Correct number of copies' );
}
