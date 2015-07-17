package XTracker::Database::Utilities;

use base 'XTracker::Database';

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;

use XTracker::Constants qw( :all );
use XTracker::DBEncode qw( decode_db encode_db );
use Try::Tiny;

=head1 NAME

XTracker::Database::Utilities

=cut

### Subroutine : last_insert_id                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub last_insert_id :Export(:DEFAULT) {

    my ( $dbh, $sequence ) = @_;
    my $id = 0;

    my $qry = "select currval( ? )";
    my $sth = $dbh->prepare($qry);
    $sth->execute($sequence);

    $sth->bind_columns( \$id );
    $sth->fetch();

    return $id;
}

### Subroutine : results_list                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub results_list :Export(:DEFAULT) {
    my ($sth) = @_;
    # this is a workaround for a (new) issue with DBI 1.620 that seems to do
    # the wrong thing if there are no rows and we ask for fetchall_arrayref()
    # to return the (sero) rows as hashrefs
    #
    # ERROR: DBI bind_columns: invalid number of arguments: got handle + 0,
    # expected handle + between 1 and -1
    #
    return []
        unless $sth->rows;

    return decode_db($sth->fetchall_arrayref( {} ));
}

### Subroutine : results_channel_list           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub results_channel_list :Export(:DEFAULT) {

    my ($sth) = @_;

    my %results;

    while ( my $row = $sth->fetchrow_hashref() ) {
        push @{ $results{$row->{sales_channel}} },$row;
    }

    return decode_db(\%results);
}

### Subroutine : results_hash                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub results_hash :Export(:DEFAULT) {

    my ($sth) = @_;
    my %results = ();

    my $id = 0;

    while ( my $row = $sth->fetchrow_hashref() ) {
        my $record = {};

        foreach my $key ( keys %$row ) {
            if ( $key eq 'id' ) {
                $id = $row->{$key};
            }
            $record->{$key} = $row->{$key};
        }

        $results{$id} = $record;
    }

    return decode_db(\%results);
}


### Subroutine : results_hash2                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub results_hash2 :Export(:DEFAULT) {

    my ( $sth, $hashkey ) = @_;
    my %results = ();

    while ( my $row = $sth->fetchrow_hashref() ) {
        my $record = {};

        foreach my $key ( keys %$row ) {
            $record->{$key} = $row->{$key};
        }

        $results{ $row->{$hashkey} } = $record;
    }

    return decode_db(\%results);
}


### Subroutine : make_placeholder               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub make_placeholder :Export( :DEFAULT ) {
    my ( $args_ref ) = @_;

    my @db_args = @{ $args_ref->{list} // [ $args_ref->{id} ] // [] };
    my $placeholder = join(',', map { '?' } @db_args);
    $placeholder = "($placeholder)" if $args_ref->{list};

    return ( \@db_args, $placeholder );
}


### Subroutine : make_update                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub make_update :Export(:DEFAULT) {

    my ($qry) = shift;

    return sub {

        my ( $dbh, $args_ref ) = @_;

        my $sth = $dbh->prepare($qry);
        $sth->execute(encode_db(@$args_ref));

        return;
    }
}


### Subroutine : make_select                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub make_select :Export(:DEFAULT) {

    my ($qry) = shift;

    return sub {

        my ( $self, $dbh, $args_ref ) = @_;

        my $sth = $dbh->prepare($qry);
        $sth->execute(encode_db(@$args_ref));

        return results_list($sth);
    }
}


# enlikening -- it's like embiggening, but likier

sub enliken :Export(:DEFAULT) {
    my @terms = @_;

    return unless @terms;

    if (wantarray) {
        return map { q{%}.escape_like_wildcards($_).q{%} } @terms;
    }
    else {
        return q{%}.escape_like_wildcards($terms[0]).q{%};
    }
}

#
# ambiguities backward-R us...
#
# NOT escape in the manner of wildcards
# BUT escape those wildcards that are recognized by SQL 'LIKE'
#

sub escape_like_wildcards :Export(:DEFAULT) {
    my $sql_value = shift;

    return unless $sql_value;

    # relies on SQL ESCAPE character default of backslash
    $sql_value =~ s{%}{\\%}g if $sql_value =~ m{%};
    $sql_value =~ s{_}{\\_}g if $sql_value =~ m{_};

    return $sql_value;
}

=head2 is_valid_database_id

Check the given argument is a Postgres integer.

=cut

sub is_valid_database_id :Export(:DEFAULT) {
    my ($input) = @_;

    return 0 unless $input;

    # if it contains non-digits
    return 0 if $input =~ m/\D/;

    # if its out of range
    return 0 if $input > $PG_MAX_INT;

    return 1;
}

=head2 sth_execute_with_error_handling

Run a DBI $sth->execute, but catch any trouble,
and reconnect to the database if it disconnects
because of e.g. a timeout.

$error_handler is an optional reference to a subroutine
which will be passed an array of any error strings.
the default is effectively: sub { shift; warn $_ for @_ }

=cut

sub sth_execute_with_error_handling :Export(:DEFAULT) {
    my ($error_handler, $dbh, $sth, @args) = @_;
    my ($rv, @errors);

    try {
        $rv = $sth->execute(@args);
        die if $dbh->err;
    }
    catch {
        push @errors, ($dbh->err ? $dbh->errstr : $_);

        # Rollback if autocommit is off
        unless ( $dbh->{AutoCommit} ) {
            try {
                $dbh->rollback;
                die if $dbh->err;
            }
            catch {
                push @errors, ($dbh->err ? $dbh->errstr : $_);
            };
        }

        # Reconnect to the database if necessary
        # e.g. on timeout errors.
        # (See also: DBD::mysql and mysql_timeout_ properties)
        unless ( $dbh->ping ) {
            push @errors, "$DB_DISCONNECTED_STRING: Trying to reconnect to database...";
            $dbh = $dbh->clone;
        }
    };

    if (@errors) {
        if ($error_handler) {
            $error_handler->(@errors);
        }
        else {
            warn $_ for @errors;
        }
    }

    return $rv;
}

1;
