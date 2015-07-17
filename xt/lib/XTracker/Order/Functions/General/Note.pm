package XTracker::Order::Functions::General::Note;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Schema;
use XTracker::Constants::FromDB qw( :note_type );
use XTracker::Database::Customer;
use XTracker::Database::Note                qw( get_note get_note_types );
use XTracker::Database::Order;
use XTracker::Database::Return;
use XTracker::Database::Shipment;
use XTracker::Database::StockTransfer       qw( get_stock_transfer );

use XTracker::Utilities                     qw( parse_url );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section info from url
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Cancel Order';
    $handler->{data}{content}       = 'ordertracker/shared/viewnote.tt';
    $handler->{data}{short_url}     = $short_url;

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "javascript:history.go(-1);" } );

    # get data from query string
    for (qw( parent_id note_category sub_id note_id shipment_id came_from search_string)) {
        $handler->{data}{$_} = $handler->{param_of}{$_};
    }

    if ( $handler->{data}{note_category} && $handler->{data}{note_category} eq 'PreOrder' ) {
        # need this to make this work under SSL as
        # all 'StockControl/Reservation/PreOrder'
        # is behind SSL
        $short_url                  .= '/PreOrder';
        $handler->{data}{short_url} = $short_url;
    }

    # if we're working on a shipment note and no shipment id defined
    # get list of shipments on order to display
    my $shipment_related = $handler->{data}{note_category} eq "Shipment" ||
        $handler->{data}{note_category} eq "Quality Control";
    if (!$handler->{data}{sub_id} && $shipment_related){
        $handler->{data}{shipments} = get_order_shipment_info( $handler->{dbh}, $handler->{data}{parent_id} );
    }
    else {

        # note id defined - we're editing a note
        if ($handler->{data}{note_id}) {
            $handler->{data}{form_submit}   = "$short_url/EditNote?note_category=$handler->{data}{note_category}&action=Update&parent_id=$handler->{data}{parent_id}&note_id=$handler->{data}{note_id}";
            $handler->{data}{subsubsection} = "Edit Note";
            $handler->{data}{note}          = get_note( $handler->{dbh}, $handler->{data}{note_category}, $handler->{data}{note_id} );
        }
        # no note id defined - we're creating a note
        else {
            $handler->{data}{form_submit}   = "$short_url/CreateNote?note_category=$handler->{data}{note_category}&sub_id=$handler->{data}{sub_id}";
            $handler->{data}{subsubsection} = "Create Note";
        }

        # get appropriate info for note type
        if ($handler->{data}{note_category} eq "Order"){
            $handler->{data}{info}  = get_order_info($handler->{dbh}, $handler->{data}{sub_id});
        }
        elsif ($shipment_related){
           $handler->{data}{info}   = get_shipment_info($handler->{dbh}, $handler->{data}{sub_id});
        }
        elsif ($handler->{data}{note_category} eq "Return"){
            $handler->{data}{info}   = get_return_info($handler->{dbh}, $handler->{data}{sub_id});
            # Set a default note type
            $handler->{data}{default_note_type_id} = $NOTE_TYPE__RETURNS;
            # If we came from returns faulty we also need to store a process
            # group id
            if ( exists $handler->{data}{came_from}
                        && $handler->{data}{came_from} eq 'returns_faulty' ) {
                $handler->{data}{process_group_id} = $handler->{param_of}{process_group_id};
            }
        }
        elsif ($handler->{data}{note_category} eq "Customer"){
           $handler->{data}{info}   = get_customer_info($handler->{dbh}, $handler->{data}{sub_id});
        }

    }

    # populate sales channel if it's not a Customer note
    if ($handler->{data}{note_category} ne "Customer") {
        # is it an order or a stock transfer
        if ( $handler->{param_of}{sample_xfer_id} ) {
            my $stock_xfer_info             = get_stock_transfer( $handler->{dbh}, $handler->{param_of}{sample_xfer_id} );
            $handler->{data}{sales_channel} = $stock_xfer_info->{sales_channel};
        }
        else {
            my $order_info                  = get_order_info( $handler->{dbh}, $handler->{data}{parent_id} );
            $handler->{data}{sales_channel} = $order_info->{sales_channel};
        }
    }

    # get list of note categories for user to select from
    if($handler->{data}{note_category} eq 'PreOrder') {
        $handler->{data}{note_types}
          = { map { $_->id => { $_->get_columns } }
                  $handler->schema->resultset('Public::PreOrderNoteType')->all};
    }
    else{
        $handler->{data}{note_types} = get_note_types( $handler->{dbh} );
        unless ( $handler->{data}{note_category} eq 'Quality Control' ) {
            delete $handler->{data}{note_types}->{ $NOTE_TYPE__QUALITY_CONTROL };
        }
    }

    return $handler->process_template;
}

1;
