package XTracker::Database::Department;

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;
#use XTracker::Database;
use XTracker::Database::Utilities   qw( &results_list );
use XTracker::Utilities             qw( number_in_list );
use XTracker::Constants::FromDB     qw( :department );


### Subroutine : get_departments                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_departments :Export() {

    my ( $dbh ) = @_;

    my $sql = qq(
                 select department
                 from department
    );

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    return results_list($sth);
}

### Subroutine : get_department_by_id           ###
# usage        : $dept=get_department_by_id($id); #
# description  : Ronseal                          #
# parameters   : $department_id                   #
# returns      : scalar [department name]         #

sub get_department_by_id :Export() {

    my ( $dbh, $id ) = @_;

    my $sql = "select department from department where id=?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($id);

    my ($name) = $sth->fetchrow_array();

    return $name;
}


=head2 is_department_in_customer_care_group

    $boolean    = is_department_in_customer_care_group( $department_id );

Checks to see whether the Department Id is part of the Customer Care Group of Departments.

=cut

sub is_department_in_customer_care_group :Export() {
    my ( $department_id )   = @_;

    my $retval  = 0;

    if ( number_in_list( $department_id, customer_care_department_group() ) ) {
        $retval = 1;
    }

    return $retval;
}

=head2 customer_care_department_group

    my $array_red   = customer_care_department_group();

This returns a list of the Customer Care Departments which are currently:

* Customer Care
* Customer Care Manager
* Personal Shopping
* Fashion Advisor

=cut

sub customer_care_department_group :Export() {

    # get the departments and sort them by Department Id
    my @depts   = sort { $a <=> $b } (
                                $DEPARTMENT__CUSTOMER_CARE,
                                $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                                $DEPARTMENT__PERSONAL_SHOPPING,
                                $DEPARTMENT__FASHION_ADVISOR,
                            );

    return ( wantarray ? @depts : \@depts );
}

1;

__END__

