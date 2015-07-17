package XTracker::Stock::Actions::PreOrderItemChangeSize;

use strict;
use warnings;

use Try::Tiny;

use XTracker::Handler;
use XTracker::Error;
use XTracker::Constants::FromDB             qw( :branding :correspondence_templates );
use XTracker::EmailFunctions                qw( get_and_parse_correspondence_template );

use XTracker::Database::Reservation         qw( get_from_email_address get_email_signoff get_email_signoff_parts );

use XTracker::WebContent::StockManagement;


sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;

    my $pre_order_id    = $handler->{param_of}{pre_order_id} // 0;
    my @changes_made;
    my @failed_to_change;

    # if any errors occur or can't change the size of ANYTHING
    my $redirect    = "/StockControl/Reservation/PreOrder/ChangeItemSize?pre_order_id=${pre_order_id}";

    my $pre_order;
    my $err;
    try {
        $pre_order  = $schema->resultset('Public::PreOrder')->find( $pre_order_id );
        $err = 0;
    }
    catch {
        xt_warn("An error occured whilst trying to get the Pre-Order:<br />$_");
        $err = 1;
    };
    return $handler->redirect_to( $redirect ) if $err;

    my $params  = $handler->{param_of};
    # get all of the Items that have been Selected to be changed
    my @item_ids_to_change  = map { /\w-(\d+)/ }
                                grep { $params->{ $_ } && /^pre_order_item-\d+$/ }
                                    keys %{ $params };
    # get all of the New Sizes for the Selected Items
    my %new_sizes_for_item  = map { $_ => $params->{ "item_new_size-$_" } }
                                grep { $params->{ "item_new_size-$_" } }
                                    @item_ids_to_change;

    if ( keys %new_sizes_for_item ) {
        my $stock_manager;
        my $variant_rs      = $schema->resultset('Public::Variant');

        try {
            $stock_manager  = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                        schema      => $schema,
                                                                        channel_id  => $pre_order->channel->id,
                                                                    } );
            # get a list of all the Pre-Order Item's matching the Id's
            my @items   = $pre_order->pre_order_items
                                        ->search( {
                                                id  => { 'in' => [ keys %new_sizes_for_item ] },
                                            } )
                                            ->order_by_id->all;
            $schema->txn_do( sub {
                foreach my $item ( @items ) {
                    my %err_result;
                    my $new_variant = $variant_rs->find( $new_sizes_for_item{ $item->id } );

                    # save what the change was
                    my $change  = {
                                    old => {
                                        item_obj        => $item,
                                        sku             => $item->variant->sku,
                                        size            => $item->variant->size->size,
                                        designer_size   => $item->variant->designer_size->size,
                                        pid             => $item->variant->product_id,
                                    },
                                    new => {
                                        sku             => $new_variant->sku,
                                        size            => $new_variant->size->size,
                                        designer_size   => $new_variant->designer_size->size,
                                        pid             => $new_variant->product_id,
                                    },
                                };

                    if ( my $new_item = $item->change_size_to( $new_variant, $stock_manager, $handler->operator_id, \%err_result ) ) {
                        $change->{new}{item_obj}    = $new_item;
                        push @changes_made, $change;
                    }
                    else {
                        $change->{failure_reason}   = $err_result{message};
                        push @failed_to_change, $change;
                    }
                }
                $stock_manager->commit();
            } );
            $err = 0;
        }
        catch {
            $stock_manager->rollback()      if ( $stock_manager );
            xt_warn("An error occured whilst trying to Change Sizes:<br />$_");
            $err = 1;
        };
        return $handler->redirect_to( $redirect ) if $err;

        $stock_manager->disconnect()        if ( $stock_manager );
    }
    else {
        xt_warn("You haven't chosen any New Sizes");
    }

    xt_warn( _render_warning_message( $handler, \@failed_to_change ) )      if ( @failed_to_change );

    if ( !@changes_made ) {
        # if NO changes were made then go back to the Selection page
        return $handler->redirect_to( $redirect );
    }

    xt_success("Changes have been Successfully made");

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Pre-Order';
    $handler->{data}{subsubsection} = 'Size Change - Customer Email';
    $handler->{data}{content}       = 'stocktracker/reservation/preorder_itemsizechange_email.tt';
    $handler->{data}{css}           = ['/css/reservations.css'];
    $handler->{data}{sales_channel} = $pre_order->channel->name;

    $handler->{data}{pre_order}     = $pre_order;
    $handler->{data}{customer}      = $pre_order->customer;
    $handler->{data}{items_changed} = [
                                        sort {
                                            $a->{old}{sku} cmp $b->{old}{sku}
                                        } @changes_made
                                      ];
    _render_email( $handler, $pre_order );

    return $handler->process_template;
}


# render the Customer Email telling them about the changes made
sub _render_email {
    my ( $handler, $pre_order ) = @_;

    my $customer        = $pre_order->customer;
    my $channel         = $pre_order->channel;
    my $branding        = $channel->branding;
    my $template_id     = $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__SIZE_CHANGE;

    # this is required for backward compatibility for the template in xTracker
    my $sign_off    = get_email_signoff( {
                                   business_id     => $channel->business->id,
                                   department_id   => $handler->department_id,
                                   operator_name   => $handler->operator->name,
                               } );
    $sign_off   =~ s{<br/>}{\n}g;      # this is NOT an HTML email

    # this supercedes the above and will be used by the Templates in the CMS
    my $sign_off_parts = get_email_signoff_parts( {
        department_id   => $handler->department_id,
        operator_name   => $handler->operator->name,
    } );

    # List of Products that are in 'items_changed' for the
    # Product Service to translate when the email is produced.
    # Get both 'old' and 'new' products.
    my %product_items   = (
        # get the Old Items
        ( map { $_->{old}{pid} => $_->{old}{item_obj}->product_details_for_email }
                @{ $handler->{data}{items_changed} } ),
        # get the New Items (should be the same products as the
        # Old but do it anyway just in case or for the future)
        ( map { $_->{new}{pid} => $_->{new}{item_obj}->product_details_for_email }
                @{ $handler->{data}{items_changed} } ),
    );

    my $email_data      = {
            pre_order_obj       => $pre_order,
            pf_pre_order_id     => $pre_order->pre_order_number,    # public facing Pre Order Id
            channel_branding    => $branding,
            sign_off            => $sign_off,
            sign_off_parts      => $sign_off_parts,
            salutation          => $channel->business->branded_salutation( {
                                                         title       => $customer->title,
                                                         first_name  => $customer->first_name,
                                                         last_name   => $customer->last_name,
                                                     } ),
            items_changed       => $handler->{data}{items_changed},
            product_items       => \%product_items,
            single_item         => ( @{ $handler->{data}{items_changed} } <= 1 ? 1 : 0 ),
            # used for the Subject
            brand_name          => $branding->{ $BRANDING__PLAIN_NAME },
            pre_order_number    => $pre_order->pre_order_number,
        };

    my $email_info = get_and_parse_correspondence_template( $handler->schema, $template_id, {
        channel     => $channel,
        data        => $email_data,
        base_rec    => $pre_order,
    } );

    my $from_address    = get_from_email_address( {
                                channel_config  => $channel->business->config_section,
                                department_id   => $handler->department_id,
                                schema          => $handler->schema,
                                locale          => $customer->locale,
                            } );

    my $email_details   = {
            template_id => $template_id,
            to          => $pre_order->customer->email,
            from        => $from_address,
            reply_to    => $from_address,
            subject     => $email_info->{subject},
            content     => $email_info->{content},
            content_type=> $email_info->{content_type},
        };

    $handler->{data}{email} = $email_details;

    return;
}

# make a nice warning message for those
# items that could not be changed
sub _render_warning_message {
    my ( $handler, $failed_to_change )  = @_;

    my $message = "";
    foreach my $change ( @{ $failed_to_change } ) {
        $message    .= "SKU: " . $change->{old}{sku} .
                       " couldn't be changed to '" . $change->{new}{sku} . "'" .
                       " because: " . $change->{failure_reason};
        $message    .= '<br>';
    }
    $message    =~ s/<br>*$//g;

    $message    = "Items Couldn't be Changed:<br>" . $message       if ( $message );

    return $message;
}

1;
