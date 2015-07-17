#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( get_schema_using_dbh get_database_handle );
use XTracker::Database::Distribution qw( get_selection_list );
use XTracker::EmailFunctions qw( send_email get_email_template );
use XTracker::Constants::FromDB   qw( :channel );
use XTracker::Config::Local qw( customercare_email );
use Data::Dump qw(pp);
use DateTime;

print STDERR "\n******* THIS SCRIPT IS NO LONGER IN USE ******* \n";
exit;

__END__
my $test_mode;            if ( @ARGV ) { $test_mode = 1 }
my $dbh                 = get_database_handle( { name => 'xtracker' } );
my $schema              = get_schema_using_dbh( $dbh, 'xtracker_schema' );
my $shipments           = $schema->resultset('Public::Shipment');
my $returns             = $schema->resultset('Public::Return')->search({ return_status_id=>2 });
my $emails              = $schema->resultset('Public::CorrespondenceTemplate');
my $cutoff              = 0; # number of seconds left at which sla is breached
my %list = %{get_selection_list($dbh)};

##################################################################################
#                       Dispatch SLA Emails
##################################################################################

foreach my $shipment_sla ( sort keys %list ){
    my $id          = $list{$shipment_sla}{shipment_id};
    my $shipment    = $shipments->find($id);
    my $time_left   = int($list{$shipment_sla}{cutoff_epoch} || 0);
    my $sla_priority= $list{$shipment_sla}{sla_priority};
    my $is_staff    = $list{$shipment_sla}{is_staff};
    my $shipment_type = $shipment->shipment_type->type;
    my $order_id    = $shipment->order->id;
    my $order_nr    = $shipment->order->order_nr;
    my $channel     = $shipment->order->channel->name;
    my $business    = $shipment->order->channel->web_name;
    $business       =~m/^(.*?)-.*?$/;
    my $channel_name= $1;
    my $email       = $shipment->order->customer->email;
    my @items       = $shipment->shipment_items;
    my @promotional_items;foreach(@items){push(@promotional_items,1) if $_->link_shipment_item__price_adjustment}
    my $sale = @promotional_items ? "Sale" : "NonSale";
    if ($time_left<$cutoff && !$is_staff && $shipment_type ne 'Premier'){
        my $subject         =   "$channel order update - $order_nr";
        my $template_name   =   "Dispatch-SLA-Breach-$business-$sale";
        my $content         =   $emails->search({ name=>$template_name })->single;
        my $customer        =   $shipment->order->customer; 
        $content            =   $content ? $content->render_template({ customer_name => $customer->first_name." ".$customer->last_name }) : print $template_name;
        my @parameters      = (
            customercare_email($channel_name),  # FROM
            customercare_email($channel_name),  # REPLY_TO
            $email,                             # TO
            $subject,                           # SUBJECT
            $content,                           # CONTENT
        );
        print pp @parameters;# if $test_mode;

        eval {
            send_email( @parameters ) unless $test_mode;
        }; warn ($@) if ($@);
    }
}
=pod
##################################################################################
#                       Returns QC SLA Emails
##################################################################################
 
#get current datetime
my $time = DateTime->from_epoch(epoch=>time);

foreach my $return ( $returns->all ){
    my $log = $return->return_status_logs->search({return_status_id=>2},{order_by=>{-desc=>'id'}})->first;
    if(defined $log){    
        my $date = $log->date;
        if ( DateTime->compare( $date->add( days => 1 ), $time ) < 0 ) {
            my $shipment        = $return->shipment;
            next unless defined $shipment->order;
            my $order_id        = $shipment->order->id;
            my $order_nr        = $shipment->order->order_nr;
            print "Shipment:" . $shipment . "order number" . $order_nr . "\n";
            my $channel         = $shipment->order->channel->name;
            my $business        = $shipment->order->channel->web_name;
            $business           =~m/^(.*?)-.*?$/;
            my $channel_name    = $1;
            my $email           = $shipment->order->customer->email; 
            my $subject         =   "$channel returns update - $order_nr";
            my $template_name   =   "ReturnsQC-SLA-Breach-$business";
            my $content         =   $emails->search({ name=>$template_name })->single;
            my $customer        =   $shipment->order->customer; 
            $content            = $content ? $content->render_template({ customer_name => $customer->first_name." ".$customer->last_name }) : print $template_name;
            my @parameters      = (
                customercare_email($channel_name),  # FROM
                customercare_email($channel_name),  # REPLY_TO
                $email,                             # TO
                $subject,                           # SUBJECT
                $content,                           # CONTENT
            );
            print pp @parameters;# if $test_mode;
            send_email( @parameters ) unless $test_mode; 
        }
    }
}
=cut
