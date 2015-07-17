#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init;

use Test::XTracker::Data;

use XTracker::Config::Local     qw( config_var );



# evil globals
our ( $control_dbh, $control_curs );

BEGIN {
    plan tests => 10 +
                  5 * 2 +    # _test_ro_dbh()
                  6 +        # _test_tr_dbh()
                  8 * 2 +    # _test_dbic_schema()
                  11 +       # _test_dbic_schema_tr_dbh()
                  6 +        # _test_dbic_schema_and_ro_dbh()
                  1 * 3 +    # _check_dbi_disconnect()
                  1 * 3      # _check_schema_disconnect()
                  ;

    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Handler');

    can_ok("XTracker::Database",qw(
                            transaction_handle
                            read_handle
                            get_database_handle
                            get_schema_using_dbh
                            get_schema_and_ro_dbh
                        ) );
}

# make DB connections
$control_dbh    = read_handle();
isa_ok($control_dbh,"DBI::db","Control DBH Connection");
$control_curs   = _define_dbh_cursors( $control_dbh );

my $ro_dbh = read_handle();
isa_ok($ro_dbh,"DBI::db","RO DBH Connection");

my $tr_dbh = transaction_handle();
isa_ok($tr_dbh,"DBI::db","TR DBH Connection");

my $schema = get_database_handle( { name => 'xtracker_schema' } );
isa_ok($schema,"XTracker::Schema","Normal DBiC Schema Connection");
$schema->storage->ensure_connected;         # make sure it's connected

my $schema_tr_dbh = get_schema_using_dbh( $tr_dbh, 'xtracker_schema' );
isa_ok($schema_tr_dbh,"XTracker::Schema","TR DBH DBiC Schema Connection");
$schema_tr_dbh->storage->ensure_connected;  # make sure it's connected

my ( $schema_ro_dbh, $ro_dbh_schema )  = get_schema_and_ro_dbh('xtracker_schema');
isa_ok($schema_ro_dbh,"XTracker::Schema","RO DBiC Connection for DBI Connection");
isa_ok($ro_dbh_schema,"DBI::db","RO DBH Connection Through RO DBiC Connection");


#---- Test the DB Handlers ------------------------------------

eval {
    _test_ro_dbh($ro_dbh,"RO DBH: ",1);
    _test_tr_dbh($tr_dbh,$schema_tr_dbh,1);
    _test_dbic_schema($schema,"Normal DBiC",1);
    _test_dbic_schema_tr_dbh($schema_tr_dbh,$tr_dbh,1);
    _test_ro_dbh($ro_dbh_schema,"RO DBH (RO DBH & DBiC): ",1);
    _test_dbic_schema($schema_ro_dbh,"RO DBiC (RO DBH & DBiC)",1);
    _test_dbic_schema_and_ro_dbh($schema_ro_dbh, $ro_dbh_schema,1);
};
# clean-up table if any failures just to make sure
if ( $@ ) {
    $control_curs->{clean_up}();
}

#--------------------------------------------------------------


# disconnect DB handlers
$control_dbh->disconnect();
$ro_dbh->disconnect();
$tr_dbh->disconnect();
$schema->storage->disconnect();
$schema_ro_dbh->storage->disconnect();

_check_dbi_disconnect($ro_dbh,"RO DBH: ",1);
_check_dbi_disconnect($tr_dbh,"TR DBH: ",1);
_check_dbi_disconnect($ro_dbh_schema,"RO DBH (RO DBH & DBiC): ",1);
_check_schema_disconnect($schema,"Normal DBiC: ",1);
_check_schema_disconnect($schema_tr_dbh,"TR DBH DBiC: ",1);
_check_schema_disconnect($schema_ro_dbh,"RO DBiC (RO DBH & DBiC): ",1);

#---- TEST FUNCTIONS ------------------------------------------

# Test the Read Only DBI connection is Read Only and
# changes can be seen using the Control Handler
# 5 Tests
sub _test_ro_dbh {
    TRACE "_test_ro_dbh: ", join", ", @_;
    my $cursors = _define_dbh_cursors( shift );
    my $label   = shift;
    my $tmp;
    my $max_id;
    my $new_id;

    SKIP: {
        skip "_test_ro_dbh",5           if (!shift);

        ($tmp)  = $cursors->{count}();
        cmp_ok($tmp,">",0,$label."Count ($tmp) > 0");

        $max_id = $cursors->{max_id}();
        cmp_ok($max_id,">",0,$label."Max Id ($max_id) > 0");

        $new_id = $cursors->{ins_record}( ($max_id + 1) );
        cmp_ok($new_id,">",$max_id,$label."New Record Created ($new_id)");

        $tmp    = $control_curs->{max_id}();
        cmp_ok($new_id,"==",$tmp,$label."New Record DOES Shows Up Using Control DBH");

        $cursors->{del_record}($new_id);
        $new_id = $cursors->{max_id}();
        cmp_ok($new_id,"==",$max_id,$label."New Record Deleted");
    }
}

# Test the Transaction DBI connection is Transactional and
# changes can not be seen using the Control Handler
# 6 Tests
sub _test_tr_dbh {
    my $dbh         = shift;
    my $cursors     = _define_dbh_cursors( $dbh );
    my $resultset   = _define_dbic_resultset( shift );
    my $tmp;
    my $max_id;
    my $new_id;

    SKIP: {
        skip "_test_ro_dbh",6           if (!shift);

        ($tmp)  = $cursors->{count}();
        cmp_ok($tmp,">",0,"TR DBH: Count ($tmp) > 0");

        $max_id = $cursors->{max_id}();
        cmp_ok($max_id,">",0,"TR DBH: Max Id ($max_id) > 0");

        $new_id = $cursors->{ins_record}( ($max_id + 1) );
        cmp_ok($new_id,">",$max_id,"TR DBH: New Record Created ($new_id)");

        $tmp = $resultset->{max_id}();
        cmp_ok($new_id,"==",$tmp,"TR DBH: New Record Can Be Seen By Shared DBiC Connection ($tmp)");

        $tmp    = $control_curs->{max_id}();
        cmp_ok($new_id,">",$tmp,"TR DBH: New Record DOES NOT Show Up Using Control DBH");

        $dbh->rollback();

        # check max id is back to how it was before inserting the record
        # after rollback
        $max_id = $cursors->{max_id}();
        cmp_ok($max_id,"<",$new_id,"TR DBH: Rollback Worked");
    }
}

# Test the normal DBiC connection in both non-transaction mode
# where changes can be seen using the Control Handler and
# transaction mode where changes can't be seen by the Control Handler
# 8 Tests
sub _test_dbic_schema {
    my $schema      = shift;
    my $resultset   = _define_dbic_resultset( $schema );
    my $label       = shift;
    my $tmp;
    my $max_id;
    my $new;
    my $new_id;

    SKIP: {
        skip "_test_dbic_schema",8           if (!shift);

        $tmp    = $resultset->{count}();
        cmp_ok($tmp,">",0,$label.": Count ($tmp) > 0");

        $max_id = $resultset->{max_id}();
        cmp_ok($max_id,">",0,$label.": Max Id ($max_id) > 0");

        $new = $resultset->{ins_record}( ($max_id + 1) );
        cmp_ok($new->id,">",$max_id,$label." Non-TR: New Record Created (".$new->id.")");

        $tmp    = $control_curs->{max_id}();
        cmp_ok($new->id,"==",$tmp,$label." Non-TR: New Record DOES Show Up Using Control DBH");

        $resultset->{del_record}($new);
        $new_id = $resultset->{max_id}();
        cmp_ok($new_id,"==",$max_id,$label." Non-TR: New Record Deleted");

        $schema->txn_do( sub {
                    $new = $resultset->{ins_record}( ($max_id + 1) );
                    cmp_ok($new->id,">",$max_id,$label." TR: New Record Created (".$new->id.")");

                    $tmp    = $control_curs->{max_id}();
                    cmp_ok($new->id,"==",$tmp,$label." TR: New Record DOES Show Up Using Control DBH");

                    $schema->txn_rollback();
                } );

        $new_id = $resultset->{max_id}();
        cmp_ok($new_id,"==",$max_id,$label." TR: Rollback Worked");
    }
}

# Test the DBiC connection made usgin the TR DBH in both non-transaction and
# transaction mode where changes shouldn't be seen by the Control Handler
# 11 Tests
sub _test_dbic_schema_tr_dbh {
    my $schema    = shift;
    my $resultset = _define_dbic_resultset( $schema );
    my $cursors   = _define_dbh_cursors( shift );
    my $tmp;
    my $max_id;
    my $new;
    my $new_id;

    SKIP: {
        skip "_test_dbic_schema_tr_dbh",11           if (!shift);

        $tmp    = $resultset->{count}();
        cmp_ok($tmp,">",0,"TR DBH DBiC: Count ($tmp) > 0");

        $max_id = $resultset->{max_id}();
        cmp_ok($max_id,">",0,"TR DBH DBiC: Max Id ($max_id) > 0");

        $new = $resultset->{ins_record}( ($max_id + 1) );
        cmp_ok($new->id,">",$max_id,"TR DBH DBiC Non-TR: New Record Created (".$new->id.")");

        $tmp    = $control_curs->{max_id}();
        cmp_ok($new->id,">",$tmp,"TR DBH DBiC Non-TR: New Record DOES NOT Show Up Using Control DBH");

        $tmp    = $cursors->{max_id}();
        cmp_ok($new->id,"==",$tmp,"TR DBH DBiC Non-TR: New Record Can Be Seen By Shared DBI Connection ($tmp)");

        $resultset->{del_record}($new);
        $new_id = $resultset->{max_id}();
        cmp_ok($new_id,"==",$max_id,"TR DBH DBiC Non-TR: New Record Deleted");

        $schema->txn_do( sub {
                    $new = $resultset->{ins_record}( ($max_id + 1) );
                    cmp_ok($new->id,">",$max_id,"TR DBH DBiC TR: New Record Created (".$new->id.")");

                    $tmp = $cursors->{max_id}();
                    cmp_ok($new->id,"==",$tmp,"TR DBH DBiC TR: New Record Can Be Seen By Shared DBI Connection ($tmp)");
                } );

        $tmp = $resultset->{max_id}();
        cmp_ok($tmp,"==",$new->id,"TR DBH DBiC TR: Still See Record Outside 'txn_do'");

        $tmp    = $control_curs->{max_id}();
        cmp_ok($new->id,">",$tmp,"TR DBH DBiC TR: New Record DOES NOT Show Up Using Control DBH");

        $schema->txn_rollback();

        $new_id = $resultset->{max_id}();
        cmp_ok($new_id,"==",$max_id,"TR DBH DBiC TR: Rollback Worked");
    }
}

# Test the DBiC and Read Only DBH connection made using
# the 'get_schema_and_ro_dbh' function can be shared in
# transaction mode
# 6 Tests
sub _test_dbic_schema_and_ro_dbh {
    my $schema    = shift;
    my $resultset = _define_dbic_resultset( $schema );
    my $cursors   = _define_dbh_cursors( shift );
    my $tmp;
    my $max_id;
    my $new;
    my $new_id;

    SKIP: {
        skip "_test_dbic_schema_and_ro_dbh",6           if (!shift);

        $tmp    = $resultset->{count}();
        cmp_ok($tmp,">",0,"RO DBH & DBiC: Count ($tmp) > 0");

        $max_id = $resultset->{max_id}();
        cmp_ok($max_id,">",0,"RO DBH & DBiC: Max Id ($max_id) > 0");

        $schema->txn_do( sub {
                    $new = $resultset->{ins_record}( ($max_id + 1) );
                    cmp_ok($new->id,">",$max_id,"RO DBH & DBiC: New Record Created (".$new->id.")");

                    $tmp    = $control_curs->{max_id}();
                    cmp_ok($new->id,"==",$tmp,"RO DBH & DBiC: New Record DOES Show Up Using Control DBH");

                    $tmp = $cursors->{max_id}();
                    cmp_ok($new->id,"==",$tmp,"RO DBH & DBiC: New Record Can Be Seen By Shared DBI Connection ($tmp)");

                    $schema->txn_rollback();
                } );

        $new_id = $resultset->{max_id}();
        cmp_ok($new_id,"==",$max_id,"RO DBH & DBiC: Rollback Worked");
    }
}

# Checks to see if a DBI connection has been disconnected
# 1 Tests
sub _check_dbi_disconnect {
    TRACE "_check_dbi_disconnect with ", join", ", @_;;
    my $dbh     = shift;
    my $label   = shift;
    my $cursors = _define_dbh_cursors( $dbh );

    SKIP: {
        skip "_check_dbi_disconnect",1          if (!shift);
        ok(!$dbh->ping, 'ping() says we have lost connection');
    }
}

# Checks to see if a DBiC Schema connection has been disconnected
# 1 Tests
sub _check_schema_disconnect {
    my $schema      = shift;
    my $label       = shift;

    SKIP: {
        skip "_check_schema_disconnect",1       if (!shift);

        my $tmp = $schema->storage->connected();
        cmp_ok($tmp,"==",0,$label."Disconnected");
    }
}

#--------------------------------------------------------------

# defines a set of commands to be used by a DBI connection
sub _define_dbh_cursors {

    my $dbh     = shift;

    my $cursors = {};
    my $sql     = "";

    my $dc_name = config_var( "DistributionCentre", "name" );

    $cursors->{count}   = sub {
            my $sql =<<SQL
SELECT  COUNT(*)
FROM    measurement
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute();
            return $sth->fetchrow_array();
        };

    $cursors->{max_id}  = sub {
            my $sql =<<SQL
SELECT  MAX(id)
FROM    measurement
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute();
            return $sth->fetchrow_array();
        };

    $cursors->{ins_record}= sub {
            my $sql =<<SQL
INSERT INTO measurement ( id, measurement) VALUES (
    ?,
    'TEST $$ MEASUREMENT NAME'
);
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
            return $cursors->{max_id}();
        };

    $cursors->{del_record}= sub {
            my $sql =<<SQL
DELETE FROM measurement WHERE id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
        };

    $cursors->{clean_up}= sub {
            my $sql =<<SQL
DELETE FROM measurement
WHERE measurement ilike 'TEST ${$}%'
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute();
        };

    return $cursors;
}

# defines a set of commands to be used by a DBiC connection
sub _define_dbic_resultset {

    my $schema      = shift;

    my $resultset   = {};
    my $rs          = $schema->resultset('Public::Measurement');

    $resultset->{count}     = sub {
            return $rs->count();
        };

    $resultset->{max_id}    = sub {
            return $rs->get_column('id')->max();
        };

    $resultset->{ins_record}= sub {
            return $rs->create( {
                    id      => shift,
                    measurement    => 'TEST $$ MEASUREMENT NAME',
                } );
        };

    $resultset->{del_record}= sub {
            my $rec     = shift;
            return $rec->delete;
        };

    return $resultset;
}
