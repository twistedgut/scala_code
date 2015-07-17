package XTracker::Database::Operator;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;
use Data::Dump qw(pp);
use Perl6::Export::Attrs;
use XTracker::Database;

sub get_operator_by_id :Export(:common) {
    my ($dbh, $operator_id) = @_;
    my ($sql, $sth, $res);

    if (not defined $operator_id) {
        Carp::carp( q{you need to specify an operator-id} );
        return;
    };

    # write, prepare and execute the search
    $sql = q[
        SELECT  *
          FROM  operator
         WHERE  operator.id = ?
    ];
    $sth = $dbh->prepare( $sql )
        or die $dbh->errstr;
    $sth->execute( $operator_id )
        or die $dbh->errstr;

    # fetch results
    # operator.id is a PK, so no need to check for multiple results
    $res = $sth->fetchrow_hashref();
    $sth->finish();

    # return a hashref for the row we matched
    return $res;
}

sub get_operator_by_username :Export(:common) {
    my ($dbh, $operator_username) = @_;
    my ($sql, $sth, $res);

    if (not defined $operator_username) {
        Carp::carp( q{you need to specify an operator-username} );
        return;
    };

    # write, prepare and execute the search
    $sql = q[
        SELECT  *
          FROM  operator
         WHERE  operator.username = ?
    ];
    $sth = $dbh->prepare( $sql )
        or die $dbh->errstr;
    $sth->execute( $operator_username )
        or die $dbh->errstr;

    # fetch results
    # operator.username is UNIQUE() so no need to check for multiple results
    $res = $sth->fetchrow_hashref();
    $sth->finish();

    # return a hashref for the row we matched
    return $res;
}

sub create_new_operator :Export(:common) {
    my ($dbh, $dataref) = @_;
    my ($sql, $sth, $res, $new_id);

    if (not defined $dataref) {
        Carp::carp( q{you need to specify data for the new operator} );
        return;
    };

    # write, prepare and execute
    $sql = q[
        INSERT INTO operator
        (name, username, password, auto_login, disabled, department_id, email_address)
        VALUES
        (?,    ?,        'new',    ?,          ?,        ?,             ?            )
    ];
    $sth = $dbh->prepare( $sql )
        or die $dbh->errstr;
    $sth->execute(
        @{ $dataref }{ qw/name username auto_login disabled department_id email_address/ },
    )
        or die $dbh->errstr;

    # get the id of the last inserted operator
    $new_id = $dbh->last_insert_id(undef, undef, undef, undef, { sequence => 'operator_id_seq' });

    return $new_id;
}

sub copy_operator_permissions :Export(:common) {
    my ($dbh, $operator1_id, $operator2_id) = @_;
    my ($select_sql, $select_sth, $select_res);
    my ($insert_sql, $insert_sth);

    if (not defined $operator1_id) {
        Carp::carp( q{you need to specify the id of the source operator} );
        return;
    };
    if (not defined $operator2_id) {
        Carp::carp( q{you need to specify the id of the destination operator} );
        return;
    };

    # select all the permissions for the first operator
    $select_sql = q[
        SELECT  authorisation_sub_section_id, authorisation_level_id
          FROM  operator_authorisation
         WHERE  operator_id = ?
    ];
    $select_sth = $dbh->prepare( $select_sql )
        or die $dbh->errstr;
    $select_sth->execute( $operator1_id )
        or die $dbh->errstr;

    # prepare insert statement for op2
    $insert_sql = q[
        INSERT INTO operator_authorisation
        (operator_id, authorisation_sub_section_id, authorisation_level_id)
        VALUES
        (?,?,?)
    ];
    $insert_sth = $dbh->prepare( $insert_sql )
        or die $dbh->errstr;

    # loop through all the permissions for op1 anhd insert them for op2
    while ($select_res = $select_sth->fetchrow_hashref()) {
        $insert_sth->execute(
            $operator2_id,
            $select_res->{authorisation_sub_section_id},
            $select_res->{authorisation_level_id},
        )
            or die $dbh->errstr;
    }

    $select_sth->finish;
    $insert_sth->finish;

    return;
}

sub get_operator_by_department :Export(:common) {

    my ( $dbh, $department_id ) = @_;

    if (not defined $department_id) {
        Carp::carp( q{you need to specify a department_id} );
        return;
    };

    my %ops = ();

    my $qry = "select id, name from operator where department_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($department_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $ops{$row->{id}} = $row->{name};
    }

    return \%ops;

}

1;
