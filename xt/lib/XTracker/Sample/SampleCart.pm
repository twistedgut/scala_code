package XTracker::Sample::SampleCart;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Constants::FromDB         qw( :authorisation_level );
use XTracker::Database::SampleRequest   qw( :SampleCart list_sample_request_types );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    if ( $handler->auth_level < $AUTHORISATION_LEVEL__OPERATOR ) {
        ## Redirect to Review Requests
        my $loc = "/Sample/ReviewRequests";
        return $handler->redirect_to( $loc );
    }

    my $action_status_msg   = $handler->{param_of}{action_status_msg} || '';
    my $error_msg           = '';
    my $request_id;
    my $request_reference   = '';
    my @sidenav;


    ## create request_type_code => request_type mapping hash
    my $sample_request_types_ref    = list_sample_request_types( { dbh => $handler->{dbh} } );
    my %request_type                = ();
    $request_type{ $_->{code} }     = $_->{type}            foreach @{$sample_request_types_ref};

    ## get operator request types
    my $operator_request_types_ref  = get_operator_request_types( { dbh => $handler->{dbh}, operator_id => $handler->operator_id } );
    my @operator_request_codes      = map { $_->{code} } grep { $_->{type} } @{$operator_request_types_ref};

    ## set default operator request type
    my $request_type_code           = (defined $handler->{param_of}{request_type_code} && $handler->{param_of}{request_type_code}) ? $handler->{param_of}{request_type_code} : $operator_request_types_ref->[0]{code};
    my $request_type                = $request_type{$request_type_code};


    if ( grep { m/prs/ } @operator_request_codes ) {
        push @sidenav,{ 'title' => 'Press Samples', url => '/StockControl/Inventory?restrict_loc=sample_room_press' };
    }
    if ( $request_type_code ne "prs" && @operator_request_codes ) {
        push @sidenav,{ 'title' => 'Sample Room', url => '/StockControl/Inventory?restrict_loc=sample_room' };
    }
    if ( @sidenav ) {
        $handler->{data}{sidenav}   = [{ 'Search' => \@sidenav }];
    }

    ## tt data
    $handler->{data}{content}               = 'stocktracker/sample/samplecart.tt';
    $handler->{data}{section}               = 'Sample';
    $handler->{data}{subsection}            = 'Sample Cart';
    $handler->{data}{subsubsection}         = "Current Items for ".$handler->{data}{name};
    $handler->{data}{operator_request_types}= $operator_request_types_ref;
    $handler->{data}{receivers}             = undef;
    $handler->{data}{request_type_code}     = undef;
    $handler->{data}{request_type}          = undef;
    $handler->{data}{action_status_msg}     = $action_status_msg;


    ## read current sample cart items for the specified operator
    my $cart_items_ref      = list_cart_items( { dbh => $handler->{dbh}, operator_id => $handler->operator_id } );
    $handler->{data}{items} = $cart_items_ref;

    if ( scalar @{$cart_items_ref} ) {
        $handler->{data}{request_type_code} = $request_type_code;
        $handler->{data}{request_type}      = $request_type;
        $handler->{data}{sales_channel}     = $cart_items_ref->[0]{sales_channel};
        if ($request_type eq 'Press') {
            $handler->{data}{receivers}     = list_sample_receivers( { dbh => $handler->{dbh} } );
        }
    }
    else {
        # reset some basics when we have an empty list

        $handler->{data}{request_type_code} = $operator_request_types_ref->[0]{code};
        $handler->{data}{request_type}      = $request_type{$operator_request_types_ref->[0]{code}};

        @sidenav    = ();

        if ( grep { m/prs/ } @operator_request_codes ) {
            push @sidenav,{ 'title' => 'Press Samples', url => '/StockControl/Inventory?restrict_loc=sample_room_press' };
        }
        if ( $handler->{data}{request_type_code} ne "prs" && @operator_request_codes ) {
            push @sidenav,{ 'title' => 'Sample Room', url => '/StockControl/Inventory?restrict_loc=sample_room' };
        }
        if ( @sidenav ) {
            $handler->{data}{sidenav}   = [{ 'Search' => \@sidenav }];
        }
    }


    return $handler->process_template( undef );
}

1;

__END__
