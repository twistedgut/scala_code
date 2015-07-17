package XTracker::Order::Finance::ViewPreOrderInvoice;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Invoice;
use XTracker::Database::Order;
use XTracker::Database::Stock qw( get_saleable_item_quantity );
use XTracker::Database::Shipment;
use XTracker::Image;
use XTracker::Order::Printing::RefundForm;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :department :shipment_item_status :pre_order_refund_status );
use XTracker::Constants::PreOrderRefund qw(:pre_order_refund_class :pre_order_refund_type );
use XTracker::Error;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section} = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'ordertracker/finance/viewpreorderinvoice.tt';
    $handler->{data}{short_url}     = $short_url;

    # get url params
    $handler->{data}{preorder_id}   = $handler->{param_of}{preorder_id};
    $handler->{data}{action}        = $handler->{param_of}{action};
    $handler->{data}{invoice_id}    = $handler->{param_of}{invoice_id};


    # auth for people to edit refunds - Customer Care Managers & Finance
    if ( grep { $_ == $handler->{data}{department_id} }
        $DEPARTMENT__FINANCE,
        $DEPARTMENT__CUSTOMER_CARE_MANAGER,
    ) {
        $handler->{data}{auth_edit} = 1;
    }

    my $schema = XTracker::Database::get_schema_using_dbh(
        $handler->{dbh}, 'xtracker_schema' );

    # get renumeration type
    $handler->{data}{renum_type}    =  $PRE_ORDER_REFUND_TYPE__REFUND_NAME;


    my $preorder_refund = $schema->resultset('Public::PreOrderRefund')
                              ->find($handler->{data}{invoice_id});

    $handler->{data}{renumeration} = $preorder_refund;

    # get list of renumeration statuses to build select field
    # ofall status -  we are interested in cancelled and complete
    my %required_status_list = (
        $PRE_ORDER_REFUND_STATUS__COMPLETE => 'value1',
        $PRE_ORDER_REFUND_STATUS__CANCELLED => 'value2',
    );

    foreach my $status ( $schema->resultset('Public::PreOrderRefundStatus')->all ) {
        if(exists( $required_status_list{$status->id} )) {
                $handler->{data}{renum_status}{$status->id}  = $status->status;
        }
    }


    # set form action url
    $handler->{data}{form_submit} = $short_url.'/UpdatePreOrderInvoice?invoice_id='.$handler->{data}{invoice_id}.'&preorder_id='.$handler->{data}{preorder_id};

    # set page title
    if ( $handler->{data}{action} eq 'Edit' ) {
        $handler->{data}{subsubsection} = 'Edit Invoice';
    }
    else {
        $handler->{data}{subsubsection} = 'View Invoice';
    }

    # get refund info
    $handler->{data}{invoice}{preorder_nr} = $preorder_refund->pre_order->pre_order_number;
    $handler->{data}{invoice}{first_name} = $preorder_refund->pre_order->customer->first_name;
    $handler->{data}{invoice}{last_name} = $preorder_refund->pre_order->customer->last_name;
    $handler->{data}{invoice}{type} = $PRE_ORDER_REFUND_TYPE__REFUND_NAME;
    $handler->{data}{invoice}{class} = $PRE_ORDER_REFUND_CLASS__REFUND_NAME;
    $handler->{data}{invoice}{status} = $preorder_refund->pre_order_refund_status->status;
    $handler->{data}{invoice}{currency} = $preorder_refund->pre_order->currency->currency;
    $handler->{data}{sales_channel} = $preorder_refund->pre_order->channel->name;


     # get refund items info
    foreach my $refund_item ($preorder_refund->pre_order_refund_items) {
        $handler->{data}{invoice_item}{$refund_item->id}{sub_total}  = $refund_item->sub_total_value;
        $handler->{data}{invoice_item}{$refund_item->id}{unit_price} = $refund_item->unit_price;
        $handler->{data}{invoice_item}{$refund_item->id}{tax}        = $refund_item->tax;
        $handler->{data}{invoice_item}{$refund_item->id}{duty}       = $refund_item->duty;
        my $variant = $refund_item->pre_order_item->variant;
        $handler->{data}{invoice_item}{$refund_item->id}{sku} = $variant->sku;
        $handler->{data}{invoice_item}{$refund_item->id}{name} = $variant->product->name;
        $handler->{data}{invoice_item}{$refund_item->id}{designer} = $variant->product->designer->designer;

    }
    $handler->{data}{invoice}{grand_total} = $preorder_refund->pre_order_refund_items->total_value;

    # get refund status log info
    $handler->{data}{invoice_log} = $preorder_refund->pre_order_refund_status_logs->status_log_for_summary_page();
    #get refund failed log info
    $handler->{data}{failed_log}  = $preorder_refund->pre_order_refund_failed_logs->list_of_failed_log();

    # populate left nav links
    if ( $handler->{data}{section} eq 'Finance' && $handler->{data}{action} eq 'Edit' ) {
    $handler->{data}{sidenav} = [{ 'None' => [{ 'title' => 'Back', 'url' => $short_url }]}];
    }
    else {
    $handler->{data}{sidenav} = [{ 'None' => [{ 'title' => 'Back', 'url' => '/StockControl/Reservation/PreOrder/Summary?pre_order_id='.$handler->{data}{preorder_id }}] }];
    }


    return $handler->process_template( undef );
}

1;
