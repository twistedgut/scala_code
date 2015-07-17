package XTracker::Search::Utilities;

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;

### Subroutine : paged                          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub paged :Export(:DEFAULT) {

    my ( $r_results, $per_page ) = @_;

    my @pagedresults = ();
    my $r_pagearray  = [];
    my $count        = 1;

    foreach
        # my $res ( sort { $b->{product_id} <=> $a->{product_id} } @$r_results )
        my $res ( sort { $a->{id} <=> $b->{id} } @$r_results )
    {

        push( @$r_pagearray, $res );
        $count++;

        if ( $count == ( $per_page + 1 ) ) {
            push( @pagedresults, $r_pagearray );
            $r_pagearray = [];
            $count       = 1;
        }
    }

    if ( scalar( @{$r_pagearray} > 0 ) ) {
        push( @pagedresults, $r_pagearray );
    }

    return \@pagedresults;
}

### Subroutine : page_to                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub page_to :Export(:DEFAULT) {

    my ( $paged_ref, $page, $per_page ) = @_;

    if ( @$paged_ref < 2 ) { return 1; }

    return ( ( $page - 1 ) * $per_page ) +
        scalar( @{ $$paged_ref[ ( $page - 1 ) ] } );
}

### Subroutine : page_from                      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub page_from :Export(:DEFAULT) {

    my ( $page, $per_page ) = @_;

    return ( ( ( $page - 1 ) * $per_page ) + 1 );
}

### Subroutine : page_numbers                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub page_numbers :Export(:DEFAULT) {

    my ( $paged ) = @_;

    my @pages = ();
    my $count = 1;
    foreach my $list ( @{$paged} ) {
        push( @pages, $count );
        $count++;
    }

    return \@pages;
}

1;
