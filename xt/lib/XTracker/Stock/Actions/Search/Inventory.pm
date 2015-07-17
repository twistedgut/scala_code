package XTracker::Stock::Actions::Search::Inventory;
use strict;
use warnings;
use Carp;
use XTracker::Handler;
use XTracker::Image                 qw( get_image_list );
use XTracker::Database              qw(get_schema_using_dbh);
use XTracker::Database::Product     qw( :DEFAULT :search );
use XTracker::Database::Stock       qw( get_on_hand_quantity );
use XTracker::Utilities             qw( url_encode );
use XTracker::Constants             qw( $PER_PAGE );
use XTracker::Constants::FromDB     qw( :department );
use XTracker::Database::Attributes  qw( get_season_atts );
use Data::Page;
use vars                            qw( $season_codes );
use XTracker::Error;
use XTracker::Utilities             qw{ trim };

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $product        = $handler->{param_of}{'product'}      || 0;
    my $page           = $handler->{param_of}{'page'}         || 1;
    my $location       = $handler->{param_of}{'location'}     || 'inventory';
    my $stockvendor    = $handler->{param_of}{'stockvendor'}  || 'both';

    my ( $product_id, $size_id ) = $product =~ m/(\d+)-?(\d+)?/xms;

    my %args        = ();

    # get params that can be stored to default the search form when next used
    my $keep_store = join q{&}, map {
        join q{=}, ( m{^keep_(.+)} ) => $handler->{param_of}{$_}
    } grep { m{^keep_.+} } keys %{$handler->{param_of}};

    # if there were any params then put them at the end of the 'New Search' link
    my $new_search_url = '/StockControl/Inventory' . ( $keep_store ? "?$keep_store" : q{} );

    my @required_fields = qw(product designer season act department keywords style_ref);
    unless ( grep { $handler->{param_of}{$_} } @required_fields ) {
        xt_warn("No search parameters were found. Please narrow your search.");
        return $handler->redirect_to($new_search_url);
    }

    foreach my $param ( keys %{$handler->{param_of}} ){
        next if $param eq 'media_type';
        next if $param eq 'page';
        next if $param eq 'product';
        next if $param eq 'action';
        next if ( $param =~ m/^keep_/ );
        next if $handler->{param_of}{$param} eq '';
        $args{$param} = trim($handler->{param_of}{$param});
    }

    $args{product_id} = $product_id if $product_id ;
    my $per_page = $PER_PAGE;
    my $html     = "";

    $handler->{data}{content}       = 'inventory/search_results.tt';
    $handler->{data}{type}          = $location;
    $handler->{data}{products}      = [];
    $handler->{data}{pages}         = [];
    $handler->{data}{search_terms}  = \%args;
    $handler->{data}{colour}        = $handler->{param_of}{'colour'};
    $handler->{data}{colour_filter} = $handler->{param_of}{'colour_filter'};
    $handler->{data}{fabric}        = $handler->{param_of}{'fabric'};
    $handler->{data}{keywords}      = $handler->{param_of}{'keywords'};
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Search Results';

    # returns a results set as an array reference
    # containing one hash per row: { 'db field name' => value, ...  }
    my $results_ref = search_product( $handler->{dbh}, \%args );

    # Redirect to product page if we only have one pid
    if (scalar @{$results_ref} == 1) {
        my $redirect_url
            = $handler->department_id == $DEPARTMENT__FINANCE
            ? "/StockControl/Inventory/FinanceView?product_id=$results_ref->[0]{id}"
            : "/StockControl/Inventory/Overview?product_id=$results_ref->[0]{id}";
        return $handler->redirect_to( $redirect_url );
    }

    $handler->{data}{sidenav}   = [{ 'None' => [{
        title => 'New Search',
        url   => $new_search_url,
    } ] }];

    # if we didn't get any results back, we might as well go back to the search
    # page
    if ((not defined $results_ref) || (!@$results_ref)) {
        xt_warn('No search results were returned.');
        # redirect back to the form
        return $handler->redirect_to($new_search_url);
    }

    my $max_results = 5000;
    if (@$results_ref > $max_results) {
        xt_warn("Too many search results were returned -- only displaying first $max_results -- please be more specific");
        @$results_ref = splice(@$results_ref, 0, $max_results);
    }

    # get season codes for sorting search results list
    $season_codes   = { map { $_->{season} => ($_->{id}*1) } @{ get_season_atts($handler->{dbh}) } };

    # use the Page module to make page jumping easier
    my $pager   = Data::Page->new();
    $pager->current_page($page);
    $pager->entries_per_page($per_page);
    $pager->total_entries( scalar(@$results_ref) );

    # use the slice method from the Page module to get the records for the current page
    my @recs_forpage            = $pager->splice( [ ( sort _sort_by_season_pid @$results_ref ) ] );
    $handler->{data}{products}  = _sum_products( $handler->{dbh}, \@recs_forpage );
    $handler->{data}{pager}     = $pager;

    # grab img hash
    $handler->{data}->{images} = get_image_list($handler->schema, \@recs_forpage );

    # To be passed to the Slugs page via POST if the user clicks the relevant button
    $handler->{data}->{pidstring}   = _make_pidlist($results_ref);

    if ( ($handler->{param_of}{media_type} // '') eq 'excel' ) {
        $handler->{data}{template_type} = "csv";
        $handler->{r}->headers_out->set( 'Content-Disposition' => q[inline; filename="] . 'search.csv' . q["] );
    }
    return $handler->process_template( undef );
}


### Subroutine : _sum_products                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _sum_products {
    my ( $dbh, $data ) = @_;

    my @new;
    foreach my $item ( @$data ) {
        my $product_id = $item->{id};
        $item->{quantity} = get_on_hand_quantity( $dbh, { type => 'product_id', id => $product_id } );
        push @new, $item;
    }

    return \@new;
}

### Subroutine : _make_pidlist                  ###
# usage        : $pidlist =                       #
#              : make_pidlist($results_ref);      #
# description  : returns an nl-separated string   #
#              : of PIDs from the search results  #
# parameters   : $results_ref                     #
# returns      : string                           #

sub _make_pidlist {
    my $res           = shift @_;
    my $separator     = shift @_ || "\n";
    my $return_string = '';

    foreach my $row ( @$res ) {
        $return_string .= $row->{id} . $separator;
    }

    return $return_string;
}


### Subroutine : _sort_by_season_pid            ###
# usage        : sort _sort_by_season_pid @array  #
# description  : Sorts the product search list    #
#                by season and then by PID.       #
# parameters   :                                  #
# returns      :                                  #

sub _sort_by_season_pid {
    return ( $season_codes->{ $a->{season} } == $season_codes->{ $b->{season} }
            ? $a->{id} <=> $b->{id}
            : $season_codes->{ $a->{season} } <=> $season_codes->{ $b->{season} } );
}

1;
