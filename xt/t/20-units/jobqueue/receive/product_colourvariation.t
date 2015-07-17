#!/usr/bin/env perl


#
# Test Receive::Product::ColourVariation job
#

use NAP::policy "tt", 'test';
use FindBin::libs;

use Data::Dump qw(pp);

use Test::Exception;


use Test::XTracker::Data;
use Test::XT::DC::JQ::Receive qw(send_job get_channels);

use Const::Fast;
const my $RECEIVER => 'XT::JQ::DC::Receive::Product::ColourVariation';

use_ok($RECEIVER) or BAIL_OUT('Syntax errors');


#--------------- Run TESTS ---------------

_test_colourvariation();

#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

sub _test_colourvariation {
    my $fake_job    = shift;

    my (undef,$pids) = Test::XTracker::Data->grab_products({
        how_many => 3,
        channel_id => (get_channels())[0],
    });

    my $prods = [ map { $_->{product} } @$pids ];

    # link a product to itself
    my $payload = {
        action  => 'add',
        pid1    => $prods->[0]->id,
        pid2    => $prods->[0]->id,
    };
    throws_ok {
        send_job( $payload, $RECEIVER );
    } qr/Cannot link product to itself/, "Cannot link product to itself";

    # PID 8 doesn't exist in the system for some reason
    $payload->{pid2} = 8;
    lives_ok {
        send_job($payload, $RECEIVER);
    } "Job ran";

    # try a working connection
    $payload->{pid2} = $prods->[1]->id,
    lives_ok {
        send_job($payload, $RECEIVER);
    } "Job ran";

    # put another one in
    $payload->{pid2} = $prods->[2]->id,
    lives_ok {
        send_job($payload, $RECEIVER);
    } "Job ran";

    # try deleting one which doesn't exist - should be fail tolerent
    $payload->{action} = 'delete';
    $payload->{pid2} = 8;
    lives_ok {
        send_job($payload, $RECEIVER);
    } "Job ran";

    # delete one that does exist
    $payload->{pid2} = $prods->[1]->id,
    lives_ok {
        send_job($payload, $RECEIVER);
    } "Job ran";

    # delete t'other
    $payload->{pid2} = $prods->[2]->id,
    lives_ok {
        send_job($payload, $RECEIVER);
    } "Job ran";
}
