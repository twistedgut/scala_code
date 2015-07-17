package XTracker::Stock::Inventory::SearchForm;
use strict;
use warnings;
use Carp;
use XTracker::Handler;
use XTracker::Database::Attributes qw( get_colour_atts
    get_colour_filter_atts
    get_designer_atts
    get_season_atts
    get_product_type_atts
    get_sub_type_atts
    get_season_act_atts
    get_classification_atts
    get_product_department_atts );
use XTracker::Database::Profile    qw( get_department );
use XTracker::Database::Channel    qw( get_channels );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $type           = 'inventory';
    my $restrict_loc   = $handler->{param_of}{restrict_loc}  || 0;
    my $restrict_type  = $handler->{param_of}{restrict_type} || 0;
    my $hide_samples   = $handler->{param_of}{hide_samples}  || 0;

    # check to see if 'rmbrlctn' has been passed so as to jump to a remembered location
    if ( exists( $handler->{param_of}{rmbrlctn} ) && $handler->{param_of}{rmbrlctn} ) {

        my $redir_val = $handler->get_cookies('RememberedLocation')
            ->get_rmbrlctn_cookie('inventory');

        if ( $redir_val ne "" ) {
            $handler->get_cookies('RememberedLocation')->expire_cookie('inventory');

            return $handler->redirect_to( $redir_val );
        }
    }

    $handler->{data}{content}           = 'inventory/search_form.tt';
    $handler->{data}{colour}            = [ 'colour',           get_colour_atts(         $handler->{dbh} )  ];
    $handler->{data}{colour_filter}     = [ 'colour_filter',    get_colour_filter_atts(  $handler->{dbh} )  ];
    $handler->{data}{designers}         = [ 'designer',         get_designer_atts(       $handler->{dbh} )  ];
    $handler->{data}{seasons}           = [ 'season',           get_season_atts(         $handler->{dbh} )  ];
    $handler->{data}{acts}              = [ 'act',              get_season_act_atts(     $handler->{dbh} )  ];
    $handler->{data}{departments}       = [ 'department',       get_product_department_atts( $handler->{dbh} ) ];
    $handler->{data}{product_types}     = [ 'product_type',     get_product_type_atts(   $handler->{dbh} )  ];
    $handler->{data}{sub_types}         = [ 'sub_type',         get_sub_type_atts(       $handler->{dbh} )  ];
    $handler->{data}{classification}    = [ 'classification',   get_classification_atts( $handler->{dbh} )  ];
    $handler->{data}{sales_channels}    = get_channels( $handler->{dbh} );
    $handler->{data}{restrict_loc}      = $restrict_loc;
    $handler->{data}{restrict_type}     = $restrict_type;
    $handler->{data}{hide_samples}      = $hide_samples;
    $handler->{data}{department}        = get_department( { dbh => $handler->{dbh}, id => $handler->operator_id } );
    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Inventory';
    $handler->{data}{subsubsection}     = 'Search';

    return $handler->process_template( undef );
}

1;
