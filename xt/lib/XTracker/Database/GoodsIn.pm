package XTracker::Database::GoodsIn;

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

    my $db  = XTracker::Database->new();
    my $dbh = $db->dbconnect_upload();

    my $self = { dbh => $dbh, };

    bless( $self, $class );
    return $self;
}

### Subroutine : list                           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub list {

    my ( $self, $filter ) = @_;
    my @results = ();

    my $qry = <<'QUERY';
     select so.stock_order_id, po.pon, p.master_sku, p.designer_code, p.description, d.designer,
            so.expected_date_string, p.product_id, p.designer_colour, p.descriptive_colour,
            pt.product_type, so.start_ship_date
     from purchase_order po, stock_order so, product p, designer d, product_type pt
     where so.purchase_order_id = po.purchase_order_id
      and so.product_id = p.product_id
      and p.designer_id = d.designer_id
      and p.product_type_id = pt.product_type_id
      and so.status < 2
      and so.start_ship_date < (current_date + 7)";
QUERY

    if ($filter) {
        $qry .= " and p.master_sku like '$filter%'";
    }

    my $sth = $self->{dbh}->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        my $record = {};
        foreach my $key ( keys %$row ) {
            $record->{$key} = $row->{$key};
        }
        push( @results, $record );
    }

    return \@results;
}

1;

