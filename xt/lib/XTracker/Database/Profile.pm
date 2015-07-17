package XTracker::Database::Profile;

use strict;
use warnings;

use Carp;
use Data::Dump qw(pp);
use Perl6::Export::Attrs;

use XTracker::Database;
use XTracker::Database::Utilities qw( &results_list );
use XTracker::Error;
use XTracker::Logfile qw(xt_logger);


sub get_operator :Export() {
    my ( $p ) = @_;

    my $sql = qq/ SELECT name, username FROM operator WHERE id = ?  /;

    my $sth = $p->{dbh}->prepare( $sql );

    $sth->execute( $p->{id} );

    my($name,$username) = $sth->fetchrow;

    return ($name, $username);
}

sub use_ldap :Export {
    my($operator_id) = @_;
    my $dbh = read_handle();
    my $sql = q[
        SELECT use_ldap FROM operator WHERE id = ?
    ];

    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute($operator_id) or die $dbh->errstr;

    return $sth->fetchrow_hashref()->{use_ldap};
}

sub db_get_department :Export {
    my($operator_id) = @_;

    my $sql = qq/
SELECT department.*
FROM (SELECT * FROM operator WHERE id = ?) o
JOIN department ON department.id = o.department_id
    /;
    my $dbh = read_handle();
    my $sth = $dbh->prepare( $sql );

    $sth->execute( $operator_id );

    # schema implies there HAS to be a dept assigned and its 1-to-1 relationship
    my $dept = $sth->fetchrow_hashref;
    $sth->finish;

    return $dept;
}

sub get_department :Export() {
    my ( $args ) = @_;

    if (not defined $args->{id}) {
        die "Missing id parameter";
    }

    my $dept = db_get_department( $args->{id} );

    return $dept->{department};

}

sub get_department_id :Export {
    my ($operator_id) = @_;
    my ($dbh, $sql, $sth, $res);

    if (use_ldap($operator_id)) {
#        warn "use_ldap =====> TRUE\n";
    } else {
#        warn "use_ldap =====> FALSE\n";
    }

    my $dept = db_get_department( $operator_id );

    return $dept->{id};
}


# parameters   : $operator_id,$section            #
# returns      : ($auth_level, $department_id)    #
sub get_authentication_information :Export {
    my ($session, $section, $sub_section) = @_;

    # given an operator ID and a section, decide what access-level they have
    # (although counter-intuitive we also fetch the department_id here - my
    # first though was to set this when a user logs in; this way if a user's
    # department gets switched, we pick it up very quickly)
    my ($dbh, $sql, $sth, $res);

    # use the read-only database handle
    $dbh = read_handle();

    # the query to lookup the information we require
    $sql = q[
        SELECT  ass.sub_section,
                level.description,
                aus.section,
                opauth.authorisation_level_id,
                op.department_id
        FROM
            (SELECT * FROM operator WHERE id = ?) op
            JOIN operator_authorisation opauth
                ON opauth.operator_id = op.id
            JOIN authorisation_level level
                ON level.id = opauth.authorisation_level_id
            JOIN (SELECT * FROM authorisation_sub_section WHERE sub_section = ?) ass
                ON ass.id = opauth.authorisation_sub_section_id
            JOIN (SELECT * FROM authorisation_section WHERE section = ?) aus
                ON aus.id = ass.authorisation_section_id
    ];

    # prepare the query
    $sth = $dbh->prepare($sql)
        or die $dbh->errstr;
    # run the query
    $sth->execute($session->{operator_id}, $sub_section, $section)
        or die $dbh->errstr;

    # if we have more than one result, we're in trouble
    if ($sth->rows > 1) {
        die qq{Too many matches for operator/section [$session->{operator_id}, $section]! "There can be only one!!"};
    }

    # fetch the first (and only) result
    $res = $sth->fetchrow_hashref();

    # store the auth-level and department_id in the session
    $session->{auth_level}      = $res->{authorisation_level_id};
    $session->{department_id}   = $res->{department_id};
    # finish with the sth
    $sth->finish;

    # and return success!
    return 1;
}


### Subroutine : get_operator_preferences                                        ###
# usage        : $hash_ptr = get_operator_preferences(                             #
#                     $dbh,                                                        #
#                     $user_id                                                     #
#                  );                                                              #
# description  : Returns an operators preferences such as preferred channel &a     #
#                default home page.                                                #
# parameters   : Database Handler & User Id                                        #

sub get_operator_preferences :Export() {
    my ($dbh, $user_id) = @_;

    my %prefs;

    my $qry =<<QRY;
SELECT op.*,
 ch.name AS sales_channel,
 b.config_section,
 REPLACE(auths.section,' ','') || '/' || REPLACE(authsubs.sub_section,' ','') AS default_home_url
FROM operator_preferences op
LEFT JOIN (channel ch JOIN business b ON ch.business_id = b.id)
     ON op.pref_channel_id = ch.id
LEFT JOIN (authorisation_sub_section authsubs JOIN authorisation_section auths ON auths.id = authsubs.authorisation_section_id)
     ON op.default_home_page = authsubs.id
WHERE operator_id = ?
QRY

    my $sth = $dbh->prepare($qry);
    $sth->execute($user_id);

    my $pref_rec = $sth->fetchrow_hashref();

    foreach my $pref ( keys %$pref_rec ) {
        next if ( $pref eq "operator_id" );

        $prefs{$pref} = $pref_rec->{$pref};
    }

    return \%prefs;
}

1;

__END__
