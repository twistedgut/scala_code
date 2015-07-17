#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

virt_vouch_email_check.t - Tests recipient email for virtual vouchers on the Order View page

=head1 DESCRIPTION

This currently tests:
    * Recipient email for Virtual gift voucher is only displayed for Customer Care/Customer Care manager
    * recipient email validation
    * Updating recipient email via UI

#TAGS fulfilment voucher orderview cando

=cut



use Data::Dump  qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];
use Test::XT::Flow;

use XTracker::Config::Local             qw( config_var sys_config_var );
use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :customer_category
                                            :flag
                                        );

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

#--------- Tests ----------------------------------------------
test_order_view_page_for_recipient_email( $schema, 1 );
#--------------------------------------------------------------
done_testing;


=head1 METHODS

=head2 test_order_view_page_for_recipient_email

    test_order_view_page_for_recipient_email( $schema, $ok_to_do_flag );

This runs through the tests as decribed in the Description on the Order View page.

=cut

sub test_order_view_page_for_recipient_email {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_order_view_page", 1       if ( !$oktodo );

        note "TESTING Order View page";

                my $framework = Test::XT::Flow->new_with_traits(
             traits => [
                  'Test::XT::Flow::CustomerCare',
                  'Test::XT::Data::Channel',
             ],
        );

        my $channel = $framework->channel( Test::XTracker::Data->channel_for_nap );
        $framework->mech->channel( $channel );

        my $order    = create_order( $framework );
        my $shipment = $order->shipments->first;
        my @items    = $shipment->shipment_items->all;

       Test::XTracker::Data->set_department( 'it.god', 'Finance' );
       $framework->login_with_permissions({
             perms => { $AUTHORISATION_LEVEL__MANAGER => [
                  'Customer Care/Customer Search',
             ]}
        });
        $framework->flow_mech__customercare__orderview( $order->id );
        ok(!defined $framework->mech->find_xpath('id("email_preview_form_'.$items[0]->id.'")')->get_node, "Did not find EMail Preview form in the page when not in 'Customer Care'");

        Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->flow_mech__customercare__orderview( $order->id );
        ok( defined $framework->mech->find_xpath('id("email_preview_form_'.$items[0]->id.'")')->get_node, "Found EMail Preview form in the page when in 'Customer Care'");

        $framework->flow_mech__customercare_orderview_recipient_email_submit($items[0]->id,"testing\@net-a-porter.com");
        $items[0]->discard_changes;
        ok($items[0]->gift_recipient_email eq "testing\@net-a-porter.com", "Email got updated");

        $framework->errors_are_fatal(0);
        $framework->flow_mech__customercare_orderview_recipient_email_submit($items[0]->id,"testingnet-a-porter.com");
        $framework->mech->has_feedback_error_ok( qr/Invalid Email - testingnet-a-porter.com/ );
        $items[0]->discard_changes;
        ok($items[0]->gift_recipient_email eq "testing\@net-a-porter.com", "Email did not get updated when using an invalid Email Address");
        $framework->errors_are_fatal(1);

     };

     return;

}



=head2 create_order

    $dbic_order = create_order( $framework );

Helper function to create a Virtual gift card Order

=cut

sub create_order {
    my $framework   = shift;

    my ($channel, $pid)  = Test::XTracker::Data->grab_products( {
        channel => 'nap',
        virt_vouchers   => {
            value => '50.00',
            how_many => 1,
        },
    } );

    shift @{ $pid }; # get rid off the first Physical Product

    # get the relevant products out of the ARRAY
    my $vvouch = $pid->[0]{product};
    isa_ok( $vvouch , 'XTracker::Schema::Result::Voucher::Product' );

    my ($order)=Test::XTracker::Data->create_db_order({
        pids => $pid,
    });

    ok($order, 'created order Id: '.$order->id);

    my  $shipment= $order->shipments->first;
    my @items   = $shipment->shipment_items->all;

    #update the shipment_item with recipient email
    $shipment->shipment_items->update( { gift_recipient_email => 'email@net-a-porter.com' } );


    return $order;
}
