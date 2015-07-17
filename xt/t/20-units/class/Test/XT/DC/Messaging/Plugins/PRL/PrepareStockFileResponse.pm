package Test::XT::DC::Messaging::Plugins::PRL::PrepareStockFileResponse;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};

use Test::XTracker::RunCondition prl_phase => 'prl';
use Test::XTracker::Data;
use Test::More::Prefix qw/test_prefix/;
use Test::XT::DC::JQ;
use XTracker::Config::Local 'config_var';
use XT::Domain::PRLs;


# Test receiving a prepare_stock_file_response
sub consume_prepare_stock_file_response : Test(3) {
    my $test = shift;

    my $jqt = Test::XT::DC::JQ->new;
    $jqt->clear_ok;

    # Try this for one defined PRL - works the same for all
    my ($prl) = XT::Domain::PRLs::get_all_prls;
    my $prl_name = $prl->name;
    test_prefix("Testing with PRL: " . $prl_name);

    # Create a message and send
    my $file_name = 'some_random_stock_file.csv';
    ok(my $template = $test->message_template( PrepareStockFileResponse => {
          file_name => $file_name,
          prl => $prl_name,
          date_time_stamp => '2012-12-14T14:32:00+0000',
    }), "create prepare_stock_file_response message");

    my $message = $template->();
    note "Send the message";
    $test->send_message($message);

    $jqt->is_last_job ({
        funcname => 'XT::JQ::DC::Receive::StockControl::ReconcilePrlInventory',
        payload => {
            prl       => $prl_name,
            file_name => $file_name,
            function  => 'reconcile',
        },
    },
    'last job is the stock file reconciliation job' );
}

1;
