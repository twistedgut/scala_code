package XTracker::Stock::Reservation::PreOrderComplete;

use strict;
use warnings;

use XTracker::Logfile                   qw( xt_logger );
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Error;
use XTracker::Utilities                 qw( format_currency );
use XTracker::Config::Local;

use XTracker::Database::Reservation     qw( :email );

use XTracker::Constants::FromDB         qw(
                                            :correspondence_templates
                                            :variant_type
                                            :reservation_status
                                            :pre_order_status
                                            :pre_order_item_status
                                            :reservation_source
                                            :branding
                                        );
use XTracker::EmailFunctions            qw( get_and_parse_correspondence_template );
use XTracker::Constants::Reservations   qw( :reservation_messages :reservation_types :pre_order_packaging_types );
use XTracker::Constants::Payment        qw( :payment_card_types );

use XTracker::DBEncode                  qw( decode_it );

use Try::Tiny;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift))->process();
}

sub new {
    my ($class, $handler) = @_;

    my $self = {
        handler => $handler,
    };

    $handler->{data}{section}            = 'Reservation';
    $handler->{data}{subsection}         = 'Customer';
    $handler->{data}{subsubsection}      = 'Pre Order Confirmation Email';
    $handler->{data}{content}            = 'stocktracker/reservation/pre_order_complete.tt';
    $handler->{data}{js}                 = '/javascript/preorder.js';
    $handler->{data}{css}                = '/css/preorder.css';
    $handler->{data}{sidenav}            = build_sidenav({
        navtype    => 'reservations',
        res_filter => 'Personal'
    });

    return bless($self, $class);
}

sub process {
    my ($self) = @_;

    my $handler    = $self->{handler};
    my $schema     = $handler->schema;
    my $stash      = $handler->session_stash;
    my $customer   = undef;
    my $channel    = undef;
    my $pre_order  = undef;

    my $pre_order_id = $handler->{param_of}{pre_order_id};
    my $template_id = $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__COMPLETE;

    try {
        my $pre_order =  $schema->resultset('Public::PreOrder')->find( $pre_order_id);
        my $shipment_address =  $schema->resultset('Public::OrderAddress')->find($pre_order->shipment_address_id);
        my $customer  = $pre_order->customer;
        my $channel   = $customer->channel;
        my $business  = $channel->business;
        my $branding  = $channel->branding;

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

        my $address;
        if( $shipment_address ) {
            $address =  $shipment_address->address_line_1.",\n";
            $address .= $shipment_address->address_line_2.",\n" if $shipment_address->address_line_2;
            $address .= $shipment_address->address_line_3.",\n" if $shipment_address->address_line_3;
            $address .= $shipment_address->towncity.",\n" if $shipment_address->towncity;
            $address .= $shipment_address->postcode.",\n" if $shipment_address->postcode;
            $address .= $shipment_address->country if $shipment_address->country;
        }

        my $email_placeholder  = {
            pre_order_obj    => $pre_order,
            pre_order_id     => $pre_order->pre_order_number,
            address          => $address,
            channel_branding => $channel->branding,
            salutation       => $business->branded_salutation( {
                title        => $customer->title,
                first_name   => $customer->first_name,
                last_name    => $customer->last_name,
                } ),
            sign_off         => $sign_off,
            sign_off_parts   => $sign_off_parts,
            # used for the Subject
            brand_name       => $branding->{ $BRANDING__PLAIN_NAME },
            pre_order_number => $pre_order->pre_order_number,
         };


        $email_placeholder->{amount}     = sprintf( "%0.2f", $pre_order->total_value );
        $email_placeholder->{currency}  = $pre_order->currency->currency;

        my $pre_order_rs = $pre_order->pre_order_items;

        my $quantity;
        my $variant_hash;
        foreach my $item ( $pre_order_rs->all ) {
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
        $email_placeholder->{product_items}    = {
            map { $_->{item_obj}->variant->product_id => $_->{item_obj}->product_details_for_email }
                    @pre_order_items,
        };

        $email_placeholder->{pre_order_items} = \@pre_order_items;

        my $email_info = get_and_parse_correspondence_template( $schema, $template_id, {
            channel     => $channel,
            data        => $email_placeholder,
            base_rec    => $pre_order,
        } );

        my $from_address = get_from_email_address( {
                                    channel_config  => $business->config_section,
                                    department_id   => $handler->department_id,
                                    schema          => $schema,
                                    locale          => $customer->locale,
                                } );

        # email content
        my $email_content   = {
            template_id => $template_id,
            to          => $pre_order->customer->email,
            from        => $from_address,
            reply_to    => $from_address,
            subject     => $email_info->{subject},
            content     => $email_info->{content},
            content_type=> $email_info->{content_type},
        };


        # set-up data for  page
        $handler->{data}{pre_order_id}  = $pre_order_id;
        $handler->{data}{pre_order}     = $pre_order;
        $handler->{data}{customer}      = $pre_order->customer;
        $handler->{data}{email}         = $email_content;
        $handler->{data}{sales_channel} = $channel->name;
    }
    catch {
        xt_warn("There was a problem rendering the Email page:<br>$_");
    };

    return $handler->process_template;
}

1;
