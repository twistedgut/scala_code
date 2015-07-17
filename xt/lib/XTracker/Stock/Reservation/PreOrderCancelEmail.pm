package XTracker::Stock::Reservation::PreOrderCancelEmail;

use strict;
use warnings;

use Try::Tiny;

use XTracker::Handler;
use XTracker::Navigation;

use XTracker::Database::Reservation     qw( :email );
use XTracker::Constants::FromDB         qw( :correspondence_templates :branding );
use XTracker::EmailFunctions            qw( get_and_parse_correspondence_template );

use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $schema      = $handler->schema;

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Customer';
    $handler->{data}{subsubsection} = 'Pre Order Cancel Email';
    $handler->{data}{content}       = 'stocktracker/reservation/pre_order_cancel_email.tt';
    $handler->{data}{js}            = '/javascript/preorder.js';

    # build side nav
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'reservations' } );

    my $pre_order_id    = $handler->{param_of}{pre_order_id};
    my $refund_id       = $handler->{param_of}{refund_id} // 0;
    my $template_id     = $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__CANCEL;

    try {
        my $pre_order   = $schema->resultset('Public::PreOrder')->find( $pre_order_id );
        my $refund      = $pre_order->pre_order_refunds->find( $refund_id );
        my $customer    = $pre_order->customer;
        my $channel     = $customer->channel;
        my $business    = $channel->business;

        my $branding    = $channel->branding;

        my $cancel_all  = ( $handler->{param_of}{cancel_all} ? 1 : 0 );
        my @cancel_item_ids;
        @cancel_item_ids= split( qr/,/, $handler->{param_of}{cancel_items} )        if ( $handler->{param_of}{cancel_items} );

        # this is required for backward compatibility for the template in xTracker
        my $sign_off    = get_email_signoff( {
                                        business_id     => $business->id,
                                        department_id   => $handler->department_id,
                                        operator_name   => $handler->operator->name,
                                    } );
        $sign_off   =~ s{<br/>}{\n}g;      # this is NOT a HTML email

        # this supercedes the above and will be used by the Templates in the CMS
        my $sign_off_parts = get_email_signoff_parts( {
            department_id   => $handler->department_id,
            operator_name   => $handler->operator->name,
        } );

        # used to process the email using TT
        my $email_data  = {
                    pre_order_obj       => $pre_order,
                    pf_pre_order_id     => $pre_order->pre_order_number,    # public facing Pre Order Id
                    channel_branding    => $branding,
                    sign_off            => $sign_off,
                    sign_off_parts      => $sign_off_parts,
                    cancel_all_flag     => $cancel_all,
                    refund_flag         => ( $refund ? 1 : 0 ),
                    salutation          => $business->branded_salutation( {
                                                                    title       => $customer->title,
                                                                    first_name  => $customer->first_name,
                                                                    last_name   => $customer->last_name,
                                                                } ),
                    # used for the Subject
                    brand_name          => $branding->{ $BRANDING__PLAIN_NAME },
                    pre_order_number    => $pre_order->pre_order_number,
                };

        if ( $refund ) {
            $email_data->{refund_obj}       = $refund;
            $email_data->{refund_total}     = sprintf( "%0.2f", $refund->total_value );
            $email_data->{refund_currency}  = $pre_order->currency->currency;
        }

        my $item_rs;    # used to get the items
                        # to show in the email

        if ( $cancel_all && !@cancel_item_ids ) {
            # if the Whole Pre-Order was cancelled meaning
            # there were NO previously cancelled items
            $item_rs    = $pre_order->pre_order_items->cancelled;
        }
        else {
            $item_rs    = $pre_order->pre_order_items
                                        ->cancelled
                                            ->search( { id => { -in => [ @cancel_item_ids ] } } );
        }

        my $quantity;
        my $variant_hash;
        foreach my $item ( $item_rs->order_by_id->all ) {
            my $qty;
            my $vid = $item->variant->id;
            if( exists $quantity->{$vid}->{'quantity'} ) {
                $quantity->{$vid}->{'quantity'}++;
            } else {
                $quantity->{$vid}->{'quantity'} = 1;
            }
            $variant_hash->{$vid} = {
                vid => $vid,
                quantity => $quantity->{$vid}->{'quantity'},
                item_obj => $item,
                item_id  => $item->id,
                variant  => $item->variant,
            };

        }

        my @pre_order_items = ( sort { $a->{vid} <=> $b->{vid} }  values (%{$variant_hash}) );


        # get details for the Products including the name which
        # will then be translated by the Product Service when
        # the Email is processed by putting them in 'product_items'
        $email_data->{product_items}    = {
            map { $_->{item_obj}->variant->product_id => $_->{item_obj}->product_details_for_email }
                    @pre_order_items,
        };

        $email_data->{pre_order_items}  = \@pre_order_items;

        my $email_info = get_and_parse_correspondence_template( $schema, $template_id, {
            channel     => $channel,
            data        => $email_data,
            base_rec    => $pre_order,
        } );

        my $from_address= get_from_email_address( {
                                    channel_config  => $business->config_section,
                                    department_id   => $handler->department_id,
                                    schema          => $schema,
                                    locale          => $customer->locale,
                                } );

        # used to hold the details of the email for the page
        my $email_details   = {
                    template_id => $template_id,
                    to          => $pre_order->customer->email,
                    from        => $from_address,
                    reply_to    => $from_address,
                    subject     => $email_info->{subject},
                    content     => $email_info->{content},
                    content_type=> $email_info->{content_type},
            };

        # set-up data for the page
        $handler->{data}{pre_order_id}  = $pre_order_id;
        $handler->{data}{pre_order}     = $pre_order;
        $handler->{data}{customer}      = $pre_order->customer;
        $handler->{data}{email}         = $email_details;
        $handler->{data}{sales_channel} = $channel->name;

        # these params should be passed back to this
        # module if the Send Email action fails
        $handler->{data}{passback}{cancel_all}  = $handler->{param_of}{cancel_all};
        $handler->{data}{passback}{cancel_items}= $handler->{param_of}{cancel_items};
        $handler->{data}{passback}{refund_id}   = $handler->{param_of}{refund_id};
    }
    catch {
        xt_warn("There was a problem rendering the Email page:<br>$_");
    };

    return $handler->process_template;
}

1;
