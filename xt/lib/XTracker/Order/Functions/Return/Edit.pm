package XTracker::Order::Functions::Return::Edit;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Image qw( get_images );
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Return;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :department :return_status :return_item_status );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Edit Return';
    $handler->{data}{content}       = 'ordertracker/returns/edit.tt';
    $handler->{data}{short_url}     = $short_url;

    $handler->{data}{yui_enabled}   = 1;
    $handler->{data}{js}            = [
        '/yui/yahoo/yahoo-min.js',
        '/yui/dom/dom-min.js',
        '/yui/calendar/calendar.js',
        '/javascript/NapCalendar.js'
    ];

    # get order_id, shipment_id and return_id from URL
    #$handler->{data}{order_id}      = $handler->{param_of}{order_id};
    #$handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    my $return_id = $handler->{param_of}{return_id};

    my $return = $return_id =~ /^\d+$/ &&
                 $return_id <= 2147483646 &&
                 $handler->{schema}->resultset('Public::Return')->find($return_id);

    if (!$return) {
        xt_warn('Return not found');
        return $handler->redirect_to( '/CustomerCare/OrderSearch' );
    }

    # get sales channel if order id defined
    my $order = $return->shipment->order;
    $handler->{data}{order}         = $order;
    $handler->{data}{sales_channel} = $order->channel->name;
    $handler->{data}{return} = $return;

    my $back_url = "$short_url/Returns/View" .
                   "?order_id=" . $order->id .
                   "&shipment_id=" . $return->shipment_id .
                   "&return_id=" . $return->id;
    push @{ $handler->{data}{sidenav}[0]{'None'} },
      { title => 'Back to Returns', url => $back_url };

    if ($handler->{request}->method ne 'POST') {
        $handler->{data}{images} = { map {
                $_->shipment_item->product_id => get_images({
                    product_id => $_->shipment_item->product_id,
                    live => 1,
                    size => 'l',
                    schema => $handler->schema,
                });
            } ( $return->return_items->all )
        };

        # I balied a bit here. This is just used to get the size as a human readable string
        $handler->{data}{shipment_items} = get_shipment_item_info(
            $handler->{schema}->storage->dbh,
            $return->shipment_id
        );
    }
    else {
        my ($expiry, $cancellation) = @{$handler->{param_of}}{qw/expiry_date cancellation_date/};

        # Stash for template
        @{$handler->{data}}{qw/expiry_date cancellation_date/} = ($expiry, $cancellation);

        if (!$expiry || !$cancellation) {
          $handler->{data}->{error_msg} = "Both date fields are required";
          return $handler->process_template( undef );
        }

        for (\$expiry, \$cancellation) {
            ## no critic(ProhibitUselessTopic,ProhibitCaptureWithoutTest)
            my $input = $$_;
            if ($$_ !~ /^(\d{4})-(\d{2})-(\d{2})\s*$/) {
                $handler->{data}->{error_msg} = "'$$_' is not a valid date";
                return $handler->process_template( undef );
            }

            $$_ = DateTime->new(year => $1, month => $2, day => $3);


            if (DateTime->compare($$_, $return->creation_date) < 0) {
                $handler->{data}->{error_msg} = "'$input' is before (or on) the return creation date";
                return $handler->process_template( undef );
            }
        }

        $return->update({expiry_date => $expiry, cancellation_date => $cancellation});
        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::Orders::Update',
            { order_id => $return->shipment->order->id, }
        );
        return $handler->redirect_to( $back_url );
    }

    return $handler->process_template( undef );
}

1;
