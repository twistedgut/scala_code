#!/usr/bin/env perl

#
# Test Receive::Product::NavigationTag job
#

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;
use XTracker::Constants::FromDB     qw( :product_attribute_type );

use Test::XTracker::RunCondition database => 'full';

use Data::Dump qw(pp);
use Test::MockObject;
use Test::Exception;


my ($schema);
BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok("XT::JQ::DC::Receive::Product::NavigationTag");
    $schema = Test::XTracker::Data->get_schema;
    isa_ok( $schema, 'XTracker::Schema' );
}


#--------------- Run TESTS ---------------

_test_navigation_tag();

#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

sub _test_navigation_tag {

    my $payload;
    my $channel     = Test::XTracker::Data->get_local_channel();
    # get a couple of Tags to apply the Products to
    my @tags        = $schema->resultset('Product::Attribute')->search(
                                                                {
                                                                    'me.channel_id' => $channel->id,
                                                                    'me.deleted'    => 0,
                                                                    'type.name'     => 'Hierarchy'
                                                                },
                                                                {
                                                                     join => 'type',
                                                                     rows => 2,
                                                                }
                                                      )->all;
    my ( $tmp, $pids )  = Test::XTracker::Data->grab_products( { how_many => 2, channel => 'nap' } );
    my @pids            = sort { $a <=> $b } ( $pids->[0]{pid}, $pids->[1]{pid} );
    my @tmp;
    my $attval          = $schema->resultset('Product::AttributeValue')->search(
                                                                            {
                                                                                product_id  => { 'IN' => \@pids },
                                                                                deleted     => 0,
                                                                            },
                                                                            {
                                                                                order_by    => 'product_id ASC',
                                                                            }
                                                                        );

    $schema->txn_do( sub {

        note "Add Products to Tag: ".$tags[0]->name;
        $payload    = [ {
                action      => 'add',
                name        => $tags[0]->name,
                channel_id  => $channel->id,
                product_ids => \@pids,
            } ];
        lives_ok( sub {
            send_job( $payload );
        }, "Add PIDs to Tag: ".$tags[0]->name );
        # get the 2 pids attribute values to check
        @tmp    = $attval->reset->search( { attribute_id => $tags[0]->id } )->all;
        ok( $tmp[0]->product_id == $pids[0] && $tmp[0]->attribute_id == $tags[0]->id,
                                            "PID: $pids[0] has Attribute Id: ".$tags[0]->id." for '".$tags[0]->name."' tag" );
        ok( $tmp[1]->product_id == $pids[1] && $tmp[1]->attribute_id == $tags[0]->id,
                                            "PID: $pids[1] has Attribute Id: ".$tags[0]->id." for '".$tags[0]->name."' tag" );

        note "Add Products to another Tag: ".$tags[1]->name;
        $payload->[0]{name} = $tags[1]->name;
        lives_ok( sub {
            send_job( $payload );
        }, "Add PIDs to Tag: ".$tags[1]->name );
        # get the 2 pids attribute values to check
        @tmp    = $attval->reset->search( { attribute_id => $tags[1]->id } )->all;
        ok( $tmp[0]->product_id == $pids[0] && $tmp[0]->attribute_id == $tags[1]->id,
                                            "PID: $pids[0] has Attribute Id: ".$tags[1]->id." for '".$tags[1]->name."' tag" );
        ok( $tmp[1]->product_id == $pids[1] && $tmp[1]->attribute_id == $tags[1]->id,
                                            "PID: $pids[1] has Attribute Id: ".$tags[1]->id." for '".$tags[1]->name."' tag" );

        note "Delete Products from last Tag: ".$tags[1]->name;
        $payload->[0]{action}   = 'delete';
        lives_ok( sub {
            send_job( $payload );
        }, "Delete PIDs from Tag: ".$tags[1]->name );
        foreach my $atval ( @tmp ) {
            $atval->discard_changes;
            cmp_ok( $atval->deleted, '==', 1, "PID: ".$atval->product_id." set as 'Deleted' for Tag: ".$tags[1]->name );
        }
        @tmp    = $attval->reset->search( { attribute_id => $tags[0]->id } )->all;
        foreach my $atval ( @tmp ) {
            $atval->discard_changes;
            cmp_ok( $atval->deleted, '==', 0, "PID: ".$atval->product_id." still NOT Deleted for first Tag: ".$tags[0]->name );
        }

        note "Delete unknown Product from Tag should die";
        $payload->[0]{name}         = $tags[0]->name;
        $payload->[0]{product_ids}  = [ -4565 ];    # invalid PID
        dies_ok( sub {
            send_job( $payload );
        }, "Delete unknown PID from Tag dies" );
        like( $@, qr/Product -4565 not found on channel/, "Got 'product not found on channel' error message" );

        $schema->txn_rollback();
    } );
}


#--------------------------------------------------------------

# Creates and executes a job
sub send_job {
    my $payload = shift;

    my $fake_job = _setup_fake_job();
    my $funcname = 'XT::JQ::DC::Receive::Product::NavigationTag';
    my $job = new_ok( $funcname => [ payload => $payload, schema => $schema ] );
    my $errstr = $job->check_job_payload($fake_job);
    die $errstr if $errstr;
    $job->do_the_task( $fake_job );

    return;
}


# setup a fake TheShwartz::Job
sub _setup_fake_job {
    my $fake = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );
    return $fake;
}
