#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mechanize;

=head1 NAME

pre_order_notes.t - Pre-Order Note Test

=head1 DESCRIPTION

Test creation of notes via an AJAX POST to the CreateNote handler.

#TAGS inventory preorder inline cando

=cut

my $schema       = Test::XTracker::Data->get_schema;
my $pre_order    = Test::XTracker::Data::PreOrder->create_complete_pre_order();
my $note_type_id = $schema->resultset('Public::PreOrderNoteType')->first->id;

my $framework = Test::XT::Flow->new_with_traits(
                  traits => [ 'Test::XT::Flow::Reservations', ],);

my $mech = $framework->mech;

$mech->do_login;
Test::XTracker::Data->set_department('it.god', 'Stock Control');
Test::XTracker::Data->grant_permissions('it.god',
                                        'Stock Control',
                                        'Reservation',
                                        2);

# NOTE: The CSRFBlock functionality has been removed for now. This test
# will fail when it is re-enabled unless it is updated. Due to the hateful
# JavaScript involved in submitting this non-form there's no easy way around
# this. Once we've finalised the CSRF solution I'll sort out a framework
# method to simplify the whole thing.

# Initial request to grab CSRF token
# $mech->add_header("X-Requested-With", "XMLHttpRequest");
# $mech->post($mech->base() . '/StockControl/Reservation/PreOrder/CreateNote');
# my $csrf_response = decode_json $mech->content();
# $mech->add_header("X-CSRF-Token", $csrf_response->{csrf_token});

# under PSGI changes if you want to fake/send ajax-ish requests you *also*
# need to set the correct header - especially if you want the correct
# content-type to be set
$mech->add_header("X-Requested-With", "XMLHttpRequest");

$mech->post_ok($mech->base() . '/StockControl/Reservation/PreOrder/CreateNote',
               { note_category    => 'PreOrder',
                 note_text        => 'Test Note',
                 parent_id        => $pre_order->id,
                 type_id          => $note_type_id,
                 sub_id           => $pre_order->id,
                 came_from        => 'PreOrder/AJAX',
               },
               'Create a note via POST');

cmp_ok( $mech->status(), '==', 200, 'Status code is OK');
cmp_ok( $mech->content_type(), 'eq', 'application/json', 'Content type is \'application/json\'' );

done_testing;
