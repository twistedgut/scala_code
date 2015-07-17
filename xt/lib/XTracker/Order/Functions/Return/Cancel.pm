package XTracker::Order::Functions::Return::Cancel;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Shipment;
use XTracker::Database::Return;
use XTracker::EmailFunctions;
use XTracker::Database::Channel qw(get_channel_details);

use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :correspondence_templates :return_item_status :shipment_type );
use XTracker::Config::Local qw( returns_email localreturns_email );


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

    $handler->{data}{section}           = $section;
    $handler->{data}{subsection}        = $subsection;
    $handler->{data}{subsubsection}     = 'Cancel Return';
    $handler->{data}{content}           = 'ordertracker/returns/cancel.tt';
    $handler->{data}{short_url}         = $short_url;

    # get order_id, shipment_id and return_id from URL
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    $handler->{data}{return_id}     = $handler->{param_of}{return_id};

    # back link for left nav
    push @{ $handler->{data}{sidenav}[0]{'None'} }, {
        'title' => "Back",
        'url'   => "$short_url/EditReturn?order_id=" . $handler->{data}{order_id} .
                   "&shipment_id=" . $handler->{data}{shipment_id} .
                   "&return_id= " . $handler->{data}{return_id}
    };

    if ( !$handler->{data}{return_id} ) {
        die 'No return id defined';
    }


    # flag to check if item status okay to cancel whole return
    $handler->{data}{items_ok} = 1;

    my $return_items = get_return_item_info( $handler->{dbh}, $handler->{data}{return_id} );

    foreach my $id ( keys %$return_items ) {
        if ( $return_items->{$id}{return_item_status_id} > $RETURN_ITEM_STATUS__AWAITING_RETURN &&
             $return_items->{$id}{return_item_status_id} < $RETURN_ITEM_STATUS__CANCELLED )
        {
            $handler->{data}{items_ok} = 0;
            last;
        }
    }

    # items booked in - cannot cancel
    if ( $handler->{data}{items_ok} == 0) {
        $handler->{data}{error_msg} = 'Items from this return have already been received, the return cannot be cancelled.';
    }

    my $email = $handler->domain('Returns')->render_email(
        { return_id => $handler->{data}{return_id} },
        $CORRESPONDENCE_TEMPLATES__CANCEL_RETURN
    );

    # set email template info
    $handler->{data}{email_info} = {
      email_to => $email->{email_to},
      email_from => $email->{email_from},
      subject => $email->{email_subject},
      content => $email->{email_body},
      email_content_type => $email->{email_content_type},
    };

    return $handler->process_template( undef );
}

1;
