package XTracker::Stock::Reservation::Listing;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Image                     qw( get_images );
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Database::Reservation     qw( :DEFAULT get_variant_upload_dates get_next_upload_variants );
use XTracker::Database::Stock           qw( get_saleable_item_quantity get_ordered_item_quantity );
use XTracker::Database::Channel         qw( get_channels );
use XTracker::Constants::FromDB         qw( :department );
use DateTime;

sub handler {
    ## no critic(ProhibitDeepNests)
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = '';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'stocktracker/reservation/listing.tt';
    $handler->{data}{css}           = [
        '/yui/tabview/assets/skins/sam/tabview.css',
        '/css/bulk_select.css',
    ];
    $handler->{data}{js}            = [
        '/yui/yahoo-dom-event/yahoo-dom-event.js',
        '/yui/element/element-min.js',
        '/yui/tabview/tabview-min.js',
        '/javascript/xui.js',
        '/javascript/bulk_select.js',
    ];
    # list type and filter settings from url or set defaults
    $handler->{data}{list_type} = $handler->{param_of}{list_type} || 'Live';
    $handler->{data}{filter}    = $handler->{param_of}{show} || 'Personal';

    $handler->{data}{subsection}    = $handler->{data}{list_type};
    $handler->{data}{subsubsection} = $handler->{data}{filter};

    # build side nav
    $handler->{data}{sidenav}   = build_sidenav({
        navtype => 'reservations_filter',
        res_list => $handler->{data}{list_type},
        res_filter => $handler->{data}{filter},
    });
    # current date for expiry date comparsions
    my $dt = DateTime->now( time_zone => "local" );
    ($handler->{data}{current_date} = $dt->ymd()) =~ s/-//g;

    # get all channels
    $handler->{data}{channels} = get_channels( $handler->{dbh} );

    # use this to store images for PIDs so that you
    # don't need to get an image you have already got
    my %pids_image;

    # filter list
    foreach my $ch_id ( keys %{ $handler->{data}{channels} } ) {
        my $args;
        my $channel = $handler->{data}{channels}{$ch_id}{name};

        # include reservation in list if
        # list type is Live and reservation status is live
        # list type is pending and reservation is pending on a live product
        # or list type is waiting or summary and reservation is pending on a non-live product

        CASE: {
            if ( $handler->{data}{list_type} eq "Live" ) {
                $args->{type}   = 'live';
                last CASE;
            }
            if ( $handler->{data}{list_type} eq "Pending" ) {
                $args->{type}   = 'pending';
                last CASE;
            }
            if ( $handler->{data}{list_type}
             and $handler->{data}{list_type} =~ m{^(?:Waiting|Summary)$} ) {
                $args->{type}   = 'waiting';
                last CASE;
            }
        };

        $args->{channel_id} = $ch_id;
        if ( $handler->{data}{filter} eq "Personal" ) {
            $args->{operator_id} = ($handler->{param_of}{alt_operator_id} // 0)
                ? $handler->{param_of}{alt_operator_id}
                : $handler->{data}{operator_id};
        }

        my $reservations = get_reservation_list( $handler->{dbh}, $args );
        $handler->{data}{reservations} = $reservations;

        foreach my $id ( keys %{ $reservations->{ $channel } } ) {
            my $reserv = $reservations->{ $channel }{$id};

            my $operator_id = $reserv->{operator_id};
            my $customer_id = $reserv->{customer_id};
            my $variant_id  = $reserv->{variant_id};
            my $reserv_id   = $reserv->{id};

            $handler->{data}{list}{ $channel }{ $operator_id }{ $customer_id }{ $reserv_id } = $reserv;

            if ( defined $reserv->{expiry_ddmmyy} ) {
                my ($dy, $mn, $yr) = split(/-/, $reserv->{expiry_ddmmyy});
                $handler->{data}{list}{ $channel }{ $operator_id }{ $customer_id }{ $reserv_id }{check_date} = $yr.$mn.$dy;
            }

            if( defined $reserv->{uploaded_ddmmyy} ) {
                $handler->{data}{list}{ $channel }{ $operator_id }{ $customer_id }{ $reserv_id }{upload_date} = $reserv->{uploaded_ddmmyy};
            }

            # get products images
            if ( $handler->{data}{list_type}
                 && $handler->{data}{list_type} =~ m{^(?:Live|Pending)$} ) {
                my $image;
                my $product_id  = $reserv->{product_id};

                $handler->{data}{list}{ $channel }{ $operator_id }{ $customer_id }{ $reserv_id }{image} = _get_image_for_pid(
                    $handler,
                    {
                        pid         => $product_id,
                        channel_id  => $ch_id,
                        live        => $reserv->{live},
                        image_cache => \%pids_image,
                    }
                );
            }

            # push data into customers lookup hash
            $handler->{data}{customer}{ $channel }{ $customer_id } = {
                name   => join(
                    q{ },
                    (
                        $reserv->{first_name},
                        $reserv->{last_name}
                    )
                ),
                number => $reserv->{is_customer_number},
            };

            # push data into operators lookup hash
            $handler->{data}{operator}{$operator_id} = $reserv->{operator_name};

            # push data into variants lookup hash
            $handler->{data}{variants}{$channel}{ $variant_id } = {
                ordered      => 0,
                waiting      => 1,
                product_id   => $reserv->{product_id},
                product_name => $reserv->{product_name},
                designer     => $reserv->{designer},
                legacy_sku   => $reserv->{legacy_sku},
            };

        }
    }

    # if we're viewing Waiting or Pending reservations get current on hand qty for variants
    if ( $handler->{data}{list_type}
     and $handler->{data}{list_type} =~ m{^(?:Waiting|Pending)$} ) {

        # use this to store stock levels for a PID
        # and all of it's variants, so that you
        # don't have to get the stock levels for a
        # product subsequent times
        my %pids_stock;

        foreach my $channel ( keys %{ $handler->{data}{variants} } ) {

            foreach my $varid ( keys %{ $handler->{data}{variants}{ $channel } } ) {

                my $stock_level;
                my $product_id      = $handler->{data}{variants}{ $channel }{ $varid }{product_id};

                # check to see if we already have stock levels available
                if ( !exists $pids_stock{ $product_id } ) {
                    # no stock, so get the levels
                    $stock_level->{free_stock}  = get_saleable_item_quantity($handler->{schema}, $product_id );

                    # only need the 'ordered' qty for 'Waiting' lists
                    if ( $handler->{data}{list_type} eq "Waiting" ) {
                        $stock_level->{ordered} = get_ordered_item_quantity( $handler->{dbh}, $product_id );
                    }

                    $pids_stock{ $product_id }  = $stock_level;         # store stock levels for later use
                }
                else {
                    $stock_level    = $pids_stock{ $product_id };       # retrieve stock levels
                }
                $handler->{data}{variants}{ $channel }{$varid}{onhand}  = $stock_level->{free_stock}{ $channel }{ $varid };

                # only need the 'ordered' qty for 'Waiting' lists
                if ( $handler->{data}{list_type} eq "Waiting" ) {
                    $handler->{data}{variants}{ $channel }{$varid}{ordered} = $stock_level->{ordered}{ $channel }{ $varid };
                }

            }
        }
    }

    # get upload dates for Waiting list view
    if ($handler->{data}{list_type} eq "Waiting"){

        # get upload dates for variants which aren't live yet
        $handler->{data}{upload} = get_variant_upload_dates($handler->{dbh});

        # get variants in the next upload
        $handler->{data}{next_upload} = get_next_upload_variants($handler->{dbh});

        # work out which customers have items in the next upload and other future uploads
        foreach my $channel ( keys %{$handler->{data}{list} }){
            foreach my $op ( keys %{$handler->{data}{list}{$channel} }){
                foreach my $cust ( keys %{$handler->{data}{list}{$channel}{$op} }){

                    $handler->{data}{customer}{$channel}{$cust}{ $op }{nextupload}  //= 0;
                    $handler->{data}{customer}{$channel}{$cust}{ $op }{otherupload} //= 0;

                    foreach my $reserv_id ( keys %{$handler->{data}{list}{$channel}{$op}{$cust} }){
                        my $varid = $handler->{data}{list}{$channel}{$op}{$cust}{$reserv_id}{variant_id};

                        if ( $handler->{data}{next_upload}{$channel}{ $varid } ) {
                            $handler->{data}{customer}{$channel}{$cust}{ $op }{nextupload}++;

                            # get images for Next Upload section only
                            my $reserv  = $handler->{data}{list}{ $channel }{ $op }{ $cust }{ $reserv_id };
                            $reserv->{image}    = _get_image_for_pid(
                                $handler,
                                {
                                    pid         => $reserv->{product_id},
                                    channel_id  => $reserv->{channel_id},
                                    live        => $reserv->{live},
                                    image_cache => \%pids_image,
                                    go_live_if_blank => 1,
                                }
                            );
                        }
                        else {
                            $handler->{data}{customer}{$channel}{$cust}{ $op }{otherupload}++;
                        }
                    }
                }
            }
        }
    }

    # only if the operator is in Personal Shopping or is a Fashion Advisor
    if ( $handler->{data}{department_id} == $DEPARTMENT__PERSONAL_SHOPPING
         || $handler->{data}{department_id} == $DEPARTMENT__FASHION_ADVISOR ) {

        my %all_operators = ();

        # Get a list of all operators in PS and FA departments
        my @operators = $handler->{schema}->resultset('Public::Operator')
            ->in_department( [
                $DEPARTMENT__PERSONAL_SHOPPING,
                $DEPARTMENT__FASHION_ADVISOR
            ] )->all;

        $handler->{data}{all_operators} = [ ];

        foreach my $op (@operators) {
            push @{ $handler->{data}{all_operators} }, {
                id => $op->id,
                name => $op->name
            };
        }

        $handler->{data}{current_operator} = ($handler->{param_of}{alt_operator_id} // 0)
            ? $handler->{param_of}{alt_operator_id}
            : $handler->{data}{operator_id};
    }

    return $handler->process_template;
}

# used to get images for a PID, pass in
# a HASH to use as a cache so repetiver
# requests aren't made
sub _get_image_for_pid {
    my ( $handler, $args )  = @_;

    my $image_cache = $args->{image_cache};
    my $product_id  = $args->{pid};
    my $live        = $args->{live};
    my $channel_id  = $args->{channel_id};
    # if get back 'blank.gif' then get live images
    # as it's worth a try
    my $go_live_if_blank = $args->{go_live_if_blank} // 0;

    my $image;

    # check to see if the image has already been got
    if ( !exists $image_cache->{ $product_id } ) {
        # no image, so get it
        $image  = get_images({
                    product_id  => $product_id,
                    schema      => $handler->schema,
                    live        => $live,
                    business_id => $handler->{data}{channels}{ $channel_id }{business_id},
                });

        # if got 'blank.gif' and wasn't getting live images in the first place
        if ( $image->[0] =~ m{/blank.gif$} && !$live && $go_live_if_blank ) {
            $image  = get_images({
                        product_id  => $product_id,
                        schema      => $handler->schema,
                        live        => 1,
                        business_id => $handler->{data}{channels}{ $channel_id }{business_id},
                    });
        }

        $image_cache->{ $product_id } = $image;     # store it for later
    }
    else {
        $image  = $image_cache->{ $product_id };    # retrieve image
    }

    return $image;
}

1;
