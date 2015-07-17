package XTracker::Database::Duty;

use strict;
use warnings;

use XTracker::Database::Utilities;
use XTracker::Database::GenerationCounters qw(increment_generation_counters);
use Perl6::Export::Attrs;



### Subroutine : get_hs_codes                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_hs_codes :Export() {

    my ($dbh ) = @_;

    my $qry = "select id, hs_code from hs_code where active = true order by hs_code";

    my $sth = $dbh->prepare($qry);
    $sth->execute( );

    return results_list($sth);
}

### Subroutine : get_hs_code                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_hs_code :Export() {

    my ( $dbh, $id ) = @_;

    my $qry = "select hs_code from hs_code where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    my $row = $sth->fetchrow_hashref();

    return $row->{hs_code} || undef;
}

### Subroutine : get_hs_code_duty_rates        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_hs_code_duty_rates :Export() {

    my ( $dbh, $hs_code_id ) = @_;

    my %data;

    my $qry = "select cdr.id, cdr.rate, c.country from country_duty_rate cdr, country c where cdr.hs_code_id = ? and cdr.country_id = c.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($hs_code_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{country} } = $row;
    }

    return \%data;

}

### Subroutine : get_country_duty_rates        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_country_duty_rates :Export() {

    my ( $dbh, $hs_code_id ) = @_;

    my %data;

    my $qry = "select cdr.id, cdr.rate, hs.hs_code from country_duty_rate cdr, hs_code hs where cdr.country_id = ? and cdr.hs_code_id = hs.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($hs_code_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{hs_code} } = $row;
    }

    return \%data;

}



### Subroutine : add_duty_rate                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub add_duty_rate :Export() {

    my ( $dbh, $hs_code_id, $country_id, $rate ) = @_;

    my $qry = "insert into country_duty_rate values (default, ?, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($country_id, $hs_code_id, $rate);
    increment_generation_counters($dbh, qw(country_duty_rate));

    return;
}


### Subroutine : add_web_duty_rate                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub add_web_duty_rate :Export() {

    my ( $dbh, $dbh_web, $hs_code_id, $country_id, $rate ) = @_;

    my $qry = "select c.code as country, hs.hs_code from country_duty_rate cdr, country c, hs_code hs
                where cdr.country_id = ?
                and cdr.hs_code_id = ?
                and cdr.country_id = c.id
                and cdr.hs_code_id = hs.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($country_id, $hs_code_id);

    my $row = $sth->fetchrow_hashref();

    my $ins_qry = "insert into country_duties values (?,?,?)";
    my $ins_sth = $dbh_web->prepare($ins_qry);
    $ins_sth->execute( $row->{hs_code}, $row->{country}, ($rate * 100) );

    return;
}

### Subroutine : update_duty_rate              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_duty_rate :Export() {

    my ( $dbh, $duty_rate_id, $rate ) = @_;

    my $qry = "update country_duty_rate set rate = ? where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($rate, $duty_rate_id);
    increment_generation_counters($dbh, qw(country_duty_rate));

    return;
}


### Subroutine : update_web_duty_rate              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_web_duty_rate :Export() {

    my ( $dbh, $dbh_web, $duty_rate_id, $rate ) = @_;

    my $qry = "select c.code as country, hs.hs_code from country_duty_rate cdr, country c, hs_code hs
                where cdr.id = ?
                and cdr.country_id = c.id
                and cdr.hs_code_id = hs.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $duty_rate_id );

    my $row = $sth->fetchrow_hashref();

    my $web_update_qry = 'update country_duties set duty_percentage = ? where hs_code = ? and country = ?';
    my $web_sth = $dbh_web->prepare($web_update_qry);
    $web_sth->execute(($rate * 100), $$row{hs_code}, $$row{country});

    return;
}


### Subroutine : create_hs_code                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_hs_code :Export() {

    my ( $dbh, $hs_code ) = @_;

    my $qry = "insert into hs_code (hs_code) values (?) returning id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($hs_code);
    increment_generation_counters($dbh, qw(hs_code));

    my $row = $sth->fetchrow_hashref();

    return $row->{id};

}

### Subroutine : create_web_hs_code                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_web_hs_code :Export() {

    my ( $dbh_web, $hs_code ) = @_;

    my $qry = "insert into hs_codes values (?, '')";
    my $sth = $dbh_web->prepare($qry);
    $sth->execute($hs_code);

    return;
}

### Subroutine : check_hs_code                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_hs_code :Export() {

    my ( $dbh, $hs_code ) = @_;

    my $hs_code_id = 0;

    my $qry = "select id from hs_code where hs_code = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($hs_code);

    my $row = $sth->fetchrow_hashref();

    $hs_code_id = $row->{id};

    return $hs_code_id;
}


1;
