package XTracker::NAPEvents::Actions::ManagePromotion;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Logfile               qw( xt_logger );
use XTracker::Error;
use XTracker::Navigation            qw( build_sidenav );
use XTracker::Database::Channel     qw( get_channels );
use XTracker::Constants::FromDB qw(
    :promotion_class
);



my $logger = xt_logger(__PACKAGE__);

sub handler {

    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;

    my $action = $handler->{param_of}{action_name} // '';

    my $promotion_rs    = $schema->resultset('Public::MarketingPromotion');
    my $promotion;
    my $channel_id;
    my $redirect_to     = "/NAPEvents/InTheBox";

    if ( $handler->{param_of}{promotion_id} ) {
        my $err;
        try {
            $promotion  = $promotion_rs->find( $handler->{param_of}{promotion_id} );
            $channel_id = $promotion->channel_id;
            $err = 0;
        }
        catch {
            xt_warn( "Couldn't find a Promotion: " . $_ );
            $err = 1;
        };
        return $handler->redirect_to( $redirect_to ) if $err;
    }

    given ( $action ) {
        when ( 'disable_promotion' ) {
            _enable_disable_promotion( $handler, $promotion, $action );
        }
        when ( 'enable_promotion' ) {
            _enable_disable_promotion( $handler, $promotion, $action );
        }
        when ( 'edit_promotion') {
            _edit_promotion( $handler, $promotion );
        }
        default {
            $promotion  = _create_promotion( $handler );
            $channel_id = $promotion->channel_id        if ( $promotion );
        }
    }

    if ( $channel_id ) {
        $redirect_to    .= "?show_channel=" . $channel_id;
    }

    return $handler->redirect_to( $redirect_to );
}


sub _enable_disable_promotion {
    my ( $handler, $promotion, $action )    = @_;

    try {
        # by default Enable
        my $state   = 1;
        my $msg     = 'enabled';
        if ( $action eq 'disable_promotion' ) {
            $state  = 0;
            $msg    = 'disabled';
        }

        $handler->schema->txn_do( sub {
            $promotion->update ( { enabled => $state } );

            $promotion->create_related( 'marketing_promotion_logs', {
                        operator_id     => $handler->operator_id,
                        enabled_state   => $state,
                } );

            xt_success( "Promotion was ${msg} succesfully" );
        } );
    }
    catch {
        $logger->warn( "Enable/Disable: " .$_ );
        xt_warn('Invalid Promotion Id: '. $_ );
    };

    return;
}

sub _edit_promotion {
    my ( $handler, $promotion )     = @_;

    # Give up if the name has changed and it already exists.
    return if
        $handler->{param_of}{title} ne $promotion->title &&
        _promotion_already_exists( $handler );

    try {
        $handler->schema->txn_do( sub {

            my $old_promotion_type = $promotion->promotion_type;

            $promotion->update({
                title                 => $handler->{param_of}{title},
                description           => $handler->{param_of}{description},
                start_date            => $handler->{param_of}{promotion_start},
                end_date              => $handler->{param_of}{promotion_end},
                is_sent_once          => $handler->{param_of}{send_once},
                message               => $handler->{param_of}{message},
                promotion_type_id     => _edit_promotion_type_if_weighted( $handler, $promotion ),
            });

            $promotion->discard_changes;
            if ( !defined $promotion->promotion_type_id && defined $old_promotion_type ) {
            # If the promotion is no longer weighted, delete the associated promotion type.

                $old_promotion_type->delete;

            }

            # Update designer list
            $promotion->reassign_designers( $handler->{param_of}{designer_list} );

            # Update customer segment list
            $promotion->reassign_customer_segments( $handler->{param_of}{segment_list} );

            $promotion->reassign_countries( $handler->{param_of}{country_list} );
            $promotion->reassign_languages( $handler->{param_of}{language_list} );
            $promotion->reassign_product_types( $handler->{param_of}{product_type_list} );
            $promotion->reassign_gender_titles( $handler->{param_of}{gender_proxy_list} );
            $promotion->reassign_customer_categories( $handler->{param_of}{customer_category_list} );

            $promotion->create_related( 'marketing_promotion_logs', {
                operator_id     => $handler->operator_id,
                enabled_state   => undef,
            });

            xt_success('Promotion was edited successfully');
        } );
    }
    catch {
        $logger->warn( "Edit: " . $_ );
        xt_warn( 'Invalid Promotion Id'. $_ );
    };

    return;
}

sub _create_promotion {
    my $handler     = shift;

    my $promotion;
    my $promotion_type;

    # Give up if it already exists.
    return if _promotion_already_exists( $handler );

    #create new promotion
    try {

        $handler->schema->txn_do( sub {

            $promotion  = $handler->schema->resultset('Public::MarketingPromotion')->create( {
                title                 => $handler->{param_of}{title},
                description           => $handler->{param_of}{description},
                channel_id            => $handler->{param_of}{channel_id},
                start_date            => $handler->{param_of}{promotion_start},
                end_date              => $handler->{param_of}{promotion_end},
                is_sent_once          => $handler->{param_of}{send_once},
                message               => $handler->{param_of}{message},
                operator_id           => $handler->operator_id,
                promotion_type_id     => _create_promotion_type_if_weighted( $handler ),
            });

            # associate any Designers to the Promotion
            $promotion->assign_designers( $handler->{param_of}{designer_list} );

            # associate any segment to the promotion
            $promotion->assign_customer_segments( $handler->{param_of}{segment_list} );

            $promotion->assign_countries( $handler->{param_of}{country_list} );
            $promotion->assign_languages( $handler->{param_of}{language_list} );
            $promotion->assign_product_types( $handler->{param_of}{product_type_list} );
            $promotion->assign_gender_titles( $handler->{param_of}{gender_proxy_list} );
            $promotion->assign_customer_categories( $handler->{param_of}{customer_category_list} );

            $logger->debug( 'New database record created #' . $promotion->id );
            xt_success( 'Promotion was created succesfully' );
        } );
    }
    catch {
        $logger->warn( "Create: " . $_ );
        xt_warn( "Cannot Create Promotion : " . $_ );
    };

    return $promotion;
}

sub _create_promotion_type {
    my ( $handler ) = @_;

    $logger->debug( "adding promotion type '$handler->{param_of}{title}'") ;

    # Create the associated Promotion Type (where the weight information
    # is stored) and return the ID.
    return $handler->schema->resultset('Public::PromotionType')
        ->create( {
            name               => $handler->{param_of}{title},
            product_type       => $handler->{param_of}{weighted_invoice},
            weight             => $handler->{param_of}{weighted_weight},
            fabric             => $handler->{param_of}{weighted_fabric},
            origin             => $handler->{param_of}{weighted_country},
            hs_code            => $handler->{param_of}{weighted_hscode},
            promotion_class_id => $PROMOTION_CLASS__IN_THE_BOX,
            channel_id         => $handler->{param_of}{channel_id},
        } )
        ->id;

}

sub _create_promotion_type_if_weighted {
    my ( $handler ) = @_;

    if ( $handler->{param_of}{is_weighted} ) {
    # If the Marketing Promotion is weighted.

        return _create_promotion_type( $handler );

    }

    # If it's not weighted, a NULL value should be returned.
    return undef;

}

sub _edit_promotion_type_if_weighted {
    my ( $handler, $promotion ) = @_;

    if ( $handler->{param_of}{is_weighted} ) {
    # If the Marketing Promotion is weighted.

        if ( $promotion->promotion_type_id ) {

            $logger->debug( 'editing promotion type ' . $promotion->promotion_type_id );

            $promotion->promotion_type->update( {
                    name               => $handler->{param_of}{title},
                    product_type       => $handler->{param_of}{weighted_invoice},
                    weight             => $handler->{param_of}{weighted_weight},
                    fabric             => $handler->{param_of}{weighted_fabric},
                    origin             => $handler->{param_of}{weighted_country},
                    hs_code            => $handler->{param_of}{weighted_hscode},
            } );

            return $promotion->promotion_type_id;

        } else {

            return _create_promotion_type( $handler );

        }

    }

    # If it's not weighted, a NULL value should be returned.
    return undef;

}

sub _promotion_already_exists {
    my ( $handler ) = @_;

    # Count how many Marketing Promotions exist with the new name.
    my $marketing_promotion_count = $handler->schema->resultset('Public::MarketingPromotion')
        ->search( {
            title => { ilike => $handler->{param_of}{title} },
        } )
        ->count;

    if ( $marketing_promotion_count > 0 ) {
    # If more than one exists (there should only be 0 or 1, but we'll
    # do this to be safe, as there is currently no constraint on title).

        # Let the user know.
        xt_warn( "The Marketing Promotion '$handler->{param_of}{title}' already exists." );

        # No point going any further.
        return 1;

    }

    if ( $handler->{param_of}{is_weighted} ) {
    # If this is a weighted promotion.

        # Search for a Promotion Type with the new name and channel_id.
        my $promotion_type = $handler->schema->resultset('Public::PromotionType')->find( {
            name       => { ilike => $handler->{param_of}{title} },
            channel_id => $handler->{param_of}{channel_id},
        } );

        if ( $promotion_type ) {
        # If it already exists.

            # Let the user know.
            xt_warn( "The Promotion Type '$handler->{param_of}{title}' already exists." );

            # Go no further.
            return 1;

        }

    }

    # If we get this far, it doesn't already exist.
    return 0;

}

1;
