package Test::NAP::StockControl::Inventory::ReconcileIwsScript;

=head1 NAME

Test::NAP::StockControl::Inventory::ReconcileIwsScript - Test the script that reconciles IWS stock with XTracker

=head1 DESCRIPTION

Test the script that reconciles IWS stock with XTracker.

#TAGS printer iws inventory movetounit

=head1 METHODS

=cut

use File::Spec::Functions qw( catfile );
use File::Copy;
use NAP::policy "tt", "test";
use Test::XTracker::RunCondition iws_phase => 2;
use parent "NAP::Test::Class";
use XTracker::Config::Local 'config_var';
use Test::XTracker::Data;
use Test::XT::Flow;
use Test::XTracker::PrintDocs;
use XT::Data::StockReconcile::IwsStockReconciler;


sub startup : Tests(startup) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Data::Quantity',
        ],
    );
}


=head2 test_inventory_reconcile

Test the reconciliation script.

=cut

sub test_inventory_reconcile : Tests() {
    my $self = shift;

    # Get some stock in XT
    my $schema = Test::XTracker::Data->get_schema;
    my $channel = $schema->resultset('Public::Channel')->enabled_channels()->slice(0,0)->single;
    my (undef,$pids) = Test::XTracker::Data->grab_products( {
        channel_id => $channel->id,
        how_many => 10,
        force_create => 1,
    } );

    # Run script to dump XT inventory
    my $workdir = '/tmp';
    my $scriptdir = catfile( config_var('SystemPaths','xtdc_base_dir'), 'script/iws_reconciliation' );
    my $db_host = config_var('Database_xtracker','db_host');
    my $db_name = config_var('Database_xtracker','db_name');
    my $dumpscript = catfile( $scriptdir, 'xt_export_all.sh' );
    my $dumpcmd = "DB_NAME='$db_name' $dumpscript $db_host $workdir";
    system($dumpcmd);

    # Copy dumped inventory to file we will treat as dump from IWS
    my $xt_dumpfile = catfile($workdir, 'xt_stock_export.csv');
    my $iws_dumpfile = catfile($workdir, 'iws_stock_export.csv');
    copy( $xt_dumpfile, $iws_dumpfile );

    # Now make some changes to XT inventory and dump the stock again. First we'll delete
    # the first two products we grabbed.
    for my $product (@$pids[0..1]) {
      $self->{framework}->data__quantity__delete_quantity_by_type({
          variant_id => $product->{variant_id},
          channel_id => $channel->id,
          status_id => 1
      });
    }

    # Now let's grab two more products
    (undef,$pids) = Test::XTracker::Data->grab_products( {
        channel_id => $channel->id,
        how_many => 2,
        force_create => 1,
    } );

    # Now run script to dump XT inventory again
    system($dumpcmd);

    # Run reconciliation of XT and IWS inventory
    my $reconciler = XT::Data::StockReconcile::IwsStockReconciler->new;
    my $discreps = $reconciler->compare_stock('/tmp');

    # Check comparison results
    my $identical = $discreps->{identical};
    my $different = $discreps->{different};
    my $ref_only = $discreps->{ref_only};
    my $comp_only = $discreps->{comp_only};
    ok( keys(%$identical) > 0, 'found some identical items (so files were generated)' );
    is( keys(%$different), 0, 'correct number of differing items' );
    is( keys(%$ref_only), 2, 'correct number of XTracker file only items' );
    is( keys(%$comp_only), 2, 'correct number of IWS file only items' );

    # Generate report from comparison
    my $starttime = time;
    ok( my $summary = $reconciler->gen_summary( $starttime ), 'generate summary' );

    # Check summary report
    ok( $summary =~ m{XTracker and IWS: 0}, 'correct number differing items in summary' );
    ok( $summary =~ m{XTracker only: 2}, 'correct number items in XTracker only' );
    ok( $summary =~ m{IWS only: 2}, 'correct number items in IWS only' );
}
