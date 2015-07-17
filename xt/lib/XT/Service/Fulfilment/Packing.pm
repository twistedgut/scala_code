package XT::Service::Fulfilment::Packing;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Class::Std;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dump qw(pp);

use XTracker::Constants::FromDB qw( :shipment_item_status );
#use Data::FormValidator;
#use Data::FormValidator::Constraints qw(:closures);
#use DateTime;

use XT::Domain::Shipment;
#use XT::Domain::Product;


#use XTracker::Promotion::Common qw( construct_left_nav );
#use XTracker::DFV qw( :promotions );
#use XTracker::Error;
#use XTracker::Handler;
#use XTracker::Logfile qw(xt_logger);
#use XTracker::Session;

use base qw/ XT::Service /;

{

    my %shipment_domain_of  :ATTR( get => 'shipment_domain',                            set => 'shipment_domain' );


    sub START {
        my($self) = @_;
        my $schema = $self->get_schema;

        $self->set_shipment_domain(
             XT::Domain::Shipment->new({ schema => $schema })
        );
    }

    sub process {
        my($self) = @_;
        my $handler = $self->get_handler();
        my $schema = $handler->{schema};

        # create objects that provide access to the tiers we want
        my $shipment = $self->get_shipment_domain;


        $handler->{data}{section}       = 'Fulfilment';
        $handler->{data}{subsection}    = 'Packing';
        $handler->{data}{subsubsection} = '';
        $handler->{data}{sidenav}       = [];

        # get list of shipments awaiting packing
        $handler->{data}{shipments} = $shipment->packing_summary( $schema ),

        # packing complete message
        $handler->{data}->{complete_msg} = 'complete';

        # datacash payment error message
        $handler->{data}->{payment_error}= 'failed';


        return;
    }

}

1;
