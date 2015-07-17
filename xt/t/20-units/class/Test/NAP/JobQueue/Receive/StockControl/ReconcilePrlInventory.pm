package Test::NAP::JobQueue::Receive::StockControl::ReconcilePrlInventory;

#
# Test the Receive::Stock::ReconcilePrlInventory job
#
use NAP::policy "tt", "test";
use Test::XTracker::RunCondition prl_phase => 'prl';
use parent "NAP::Test::Class";
use XTracker::Config::Local 'config_var';
use XT::JQ::DC::Receive::StockControl::ReconcilePrlInventory;
use Test::XTracker::Data;
use boolean; # true/false

# Test the key methods in StockControl::PrlStockReconcile
sub test_inventory_reconcile : Tests() {
    my $self = shift;

    # Get some stock in XT
    my $channel = $self->schema->resultset('Public::Channel')->enabled_channels()->slice(0,0)->single;
    my (undef,$pids) = Test::XTracker::Data->grab_products( {
        channel_id => $channel->id,
        how_many => 10,
        force_create => true,
    } );

    # Make a worker so we can test its methods
    my $amq_identifier = 'Full';
    my $prl =  XT::Domain::PRLs::get_prl_from_amq_identifier({
        amq_identifier => $amq_identifier,
    });
    my $path = XT::Domain::PRLs::lookup_config_value({
        from_key => 'name',
        from_value => $prl->name,
        to => 'stock_file_directory',
    });
    my $testfilename = 'testfilename';
    my $payload = { function => 'dump', prl => $prl->name };
    my $worker = XT::JQ::DC::Receive::StockControl::ReconcilePrlInventory->new({ payload => $payload });

    # Test method that generates path to PRL stock file
    my $prl_fullpath = $worker->get_prl_stockfile( $prl, $testfilename);
    is( $prl_fullpath, File::Spec->catfile($path,$testfilename), 'construct path to PRL stock file' );

    # Generate an XTracker stock dump
    $worker->gen_xt_stockfile( $prl );

    # Generate a fake PRL stock dump from the XTracker dump
    ok( my $xt_fullpath = $worker->xt_stockfile_fullpath( $prl->identifier_name ), 'get fullpath to XTracker stock file' );
    ok( $prl_fullpath = $self->_generate_fake_prl_stock_dump($xt_fullpath, $pids),
        'generate fake PRL stock dump' );

    # Run comparison of the two stock dumps
    ok( my $discreps = $worker->compare_stock( $prl, $prl_fullpath ), 'stock file comparision');

    # Check comparison results
    my $different = $discreps->{different};
    my $ref_only = $discreps->{ref_only};
    my $comp_only = $discreps->{comp_only};
    my $comp_zero = $discreps->{comp_zero};
    is( keys(%$different), 2, 'correct number of differing items' );
    is( keys(%$ref_only), 2, 'correct number of XTracker file only items' );
    is( keys(%$comp_only), 1, 'correct number of PRL file only items' );
    is( keys(%$comp_zero), 1, 'correct number of zero PRL file items' );

    # Generate report from comparison
    my $starttime = time;
    ok( my $summary = $worker->gen_summary( $starttime ), 'generate summary' );

    # Check summary
    ok( $summary =~ m{XTracker and PRL Full: 2}, 'correct number differing items in summary' );
    ok( $summary =~ m{XTracker only: 2}, 'correct number items in XTracker only' );
    ok( $summary =~ m{PRL Full only: 1}, 'correct number items in PRL only' );

    # Check emailing details
    ok( my $details = $worker->reconciler->_gen_email_info($summary, $testfilename, $prl),
        'create emailing details' );
    is( $details->{sender}, config_var('Email', 'xtracker_email'), 'sender email address' );
    ok( $details->{subject} =~ 'XTracker Stock Reconciliation Report for PRL', 'email subject' );
    is( $details->{message_body}, $summary, 'email body' );
}


# Generate fake PRL stock dump from a given XTracker stock dump, with some discrepancies
sub _generate_fake_prl_stock_dump {
    my ( $self, $xt_fullpath, $pids )  = @_;

    # Open XTracker stock dump and read past header line
    open (my $xfh, '<:utf8', $xt_fullpath);
    diag $xt_fullpath;
    my $header = <$xfh>;

    # Open PRL stock dump and write header line
    my $pfh = File::Temp->new(DIR => '/tmp', UNLINK => 0);
    my $filename = $pfh->filename;
    binmode( $pfh, ":utf8" );
    print $pfh qq{Client,SKU,"Stock Status","Allocated Quantity","Free Quantity"\n};

    # Read through the XTracker stock file and write an equivalent PRL stock file, but adding some
    # discrepancies
    while (my $line = <$xfh>) {
        chomp $line;
        my ($channel,$sku,$status,$allocated,$available) = split( /,/, $line);

        # Select SKUs to mangle
        my $remove_sku      = $pids->[0]{sku};
        my $add_sku         = '99-998';
        my $increase_sku    = $pids->[1]{sku};
        my $decrease_sku    = $pids->[2]{sku};
        my $zero_sku        = $pids->[3]{sku};
        my $zero_sku_newsku = '99-999';

        # Change SKU of first item which will cause comparison to find a missing SKU and an added SKU
        if ($sku eq $remove_sku) {
          $sku = $add_sku;
        }
        elsif ($sku eq $increase_sku) {
          $available++;
        }
        elsif ($sku eq $decrease_sku) {
          $available++;
        }
        elsif ($sku eq $zero_sku) {
          $available = 0;
          $sku = $zero_sku_newsku
        }

        print $pfh "$channel,$sku,$status,$allocated,$available\n";
    }

    close($xfh);
    close($pfh);

    return $filename;
}
