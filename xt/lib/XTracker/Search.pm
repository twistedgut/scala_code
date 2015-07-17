package XTracker::Search;

use strict;
use warnings;

use XTracker::Database;

### Subroutine : new                            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub new {
    my ($class) = @_;
    my $self = {};
    bless( $self, $class );
    return $self;
}

### Subroutine : search                         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub search {

    my ( $self, $qry ) = @_;

    my $results;

    # -- code reference to a search method
    # -- this could be plucene or some other method
    # -- e.g. sql full text index, kinosearch etc

    if ( $qry =~ m /select/i ) {
        $results = $self->sql_search($qry);
    }
    else {
        $results = $self->plu_search($qry);
    }

    return $results;
}

### Subroutine : paged                          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub paged {

    my ( $self, $r_results, $per_page ) = @_;

    my @pagedresults = ();
    my $r_pagearray  = [];
    my $count        = 1;

    foreach
        my $res ( sort { $b->{product_id} <=> $a->{product_id} } @$r_results )
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

sub page_to {

    my ( $self, $paged, $page, $per_page ) = @_;

    return ( ( $page - 1 ) * $per_page ) +
        scalar( @{ $$paged[ ( $page - 1 ) ] } );
}

### Subroutine : page_from                      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub page_from {

    my ( $self, $page, $per_page ) = @_;

    return ( ( ( $page - 1 ) * $per_page ) + 1 );
}

### Subroutine : page_numbers                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub page_numbers {

    my ( $self, $paged ) = @_;

    my @pages = ();
    my $count = 1;
    foreach my $list ( @{$paged} ) {
        push( @pages, $count );
        $count++;
    }

    return \@pages;
}

1;

