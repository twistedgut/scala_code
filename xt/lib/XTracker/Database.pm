package XTracker::Database;
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt", 'exporter';

use Carp qw(carp croak confess);
use NAP::Carp qw(cluck);

use Data::Dump qw(pp);
use Module::Runtime 'require_module';
use Perl6::Export::Attrs;

#use cTracker::Schema;                   # because we're using a DBIx::Class schema to interact with cTracker data
use DBI;                                # for standard DBI connections
use DBIx::Class::QueryLog::Analyzer;
use DBIx::Class::QueryLog;
use XTracker::Logfile qw(xt_logger);    # because sometimes it's useful to throw stuff into the logfile
use XTracker::Config::Local             # because we want to access Config data
    qw(
        config_var
        config_section_exists
    );
use CustomLogger;
use PerlIO::via::CustomLogger;

=head1 NAME

XTracker::Database - the database handle provider

=head1 DESCRIPTION

As part of the "xtracker united" project the way we handled database
connections required consolidation. This module is an attempt to do that.

Note that whenever you want a db connection to xtracker, you should be using
the singleton dbh unless you have a very good use case.

=head1 SYNOPSIS

    use XTracker::Database; # you'll need to declare your imported methods

    # This is what you normally want to do - it returns you XT's singleton
    # schema
    my $schema = xtracker_schema;

    # If you want a (singleton) dbh, do the following:
    my $dbh = $schema->storage->dbh;

    # If you want to acquire your singleton schema from your singleton dbh
    $schema = get_schema_using_dbh( $dbh );

    # If you want to do some evil stuff (please don't do this, and read the
    # sub's POD before you do) and want an XT schema *without* the singleton,
    # do the below
    my $non_singleton_schema = xtracker_schema_no_singleton;

    # If you're on crack and want a DBIC-hating dbh (in other words please
    # don't do this), you *can* do the following
    my $xtracker_dbh_no_autocommit = xtracker_schema_no_autocommit;

    # If you want a non-xt dbh (there are some use cases), use db_connection
    my $connection = db_connection({
        name => $db_name,
        autocommit => 1,
    });

=cut

=head1 FUNCTIONS

=cut

sub _connection_string {
    my $connection_params = shift;

    if (not defined $connection_params->{db_name}) {
        warn "db_name: not defined";
        return;
    }
    if (not defined $connection_params->{db_type}) {
        warn "db_type: not defined";
        return;
    }

    # create the basic string
    my $connection_string =
          q{dbi:}
        . $connection_params->{db_type}
        . q{:dbname=}
        . $connection_params->{db_name}
    ;

    # only add the host if it's defined in the hashref
    if (defined $connection_params->{db_host}) {
        $connection_string =
              $connection_string
            . q{;host=}
            . $connection_params->{db_host}
        ;
    }

    # if we're mysql add a compression setting to the DSN
    # *** default to ON ***
    #   we only need to change the config files if we *DON'T* want the new,
    #   preferred compression
    if ('mysql' eq $connection_params->{db_type}) {
        my $do_compression;
        if (not defined $connection_params->{compress}) {
            $do_compression = 1;
        }
        else {
            $do_compression =
                  $connection_params->{compress}
                ? 1
                : 0
                ;
        }

        # append to the existing $dsn
        $connection_string =
              $connection_string
            . q{;mysql_compression=}
            . $do_compression
        ;

        # add timeout connection params to the dsn
        my $timeout_connection_string = join (
            ';',
            map  { sprintf "%s=%s", $_, $connection_params->{$_} }
            grep { defined $connection_params->{$_} }
            qw(mysql_write_timeout mysql_read_timeout mysql_connect_timeout)
        );
        $connection_string .= ';' . $timeout_connection_string if $timeout_connection_string;
    }

    # return the DSN connection string
    return $connection_string;
}

=head2 db_connection({ :$name!, :autocommit, :connect_object }) : a database connection (e.g. DBIx::Class::Schema or DBI)

Return a database connection for the given parameters.

=head3 IMPORTANT NOTE

B<CALLING THIS METHOD DIRECTLY DOESN'T SET THE XT SINGLETON FOR XT DBHS>. If
you want an xtracker database handle call one of the other subs in this module
(such as L<xtracker_schema>) - calling this directly won't set the singleton,
and that way leads the path to further insanity. But please use this sub
instead of the evil L<get_database_handle> in this module.

=cut

sub db_connection {
    my ($argref) = @_;

    # get a block of useful information from the configuration file
    my $connection_params = _db_connect_params($argref);

    # build the DSN string for the connection
    my $connection_string = _connection_string( $connection_params );

    # setting this will populate pg_stat_activity for any running queries and make
    # debugging *so* much easier
    $ENV{PGAPPNAME} = substr(
        $$ . " : " . $0 =~ s!/opt/xt/deploy/xtracker/!!r,
        0, 63);

    # setting up timezone for postgres database
    $ENV{PGTZ} = config_var('DistributionCentre', 'timezone');

    # get a connection to the database
    my $connection;
    eval {
        $connection = $connection_params->{connect_object}->connect(
            $connection_string,
            $connection_params->{db_user},
            $connection_params->{db_pass},
            $connection_params->{attribs},
        );
        if(my $dbic_trace = $ENV{DBIC_TRACE_CALLSTACK}) {
            try {
                require DBIx::Class::Profiler::CallStack;
                DBIx::Class::Profiler::CallStack->enable_for_schema($connection);
            }
            catch {
                xt_logger->error(
                    "DBIC_TRACE_CALLSTACK is set, but could not enable the Profiler::CallStack: $_"
                );
            };
        }
    };
    if (my $e = $@) {
        die $e;
    }

    return $connection;
}

sub _db_connect_params {
    my $argref = shift;

    if ('HASH' ne ref($argref)) {
        confess (q{$argref must be a hash-reference});
    }
    for my $param ( qw/name autocommit/ ) {
        croak("_db_connect_params requires a value for $param")
            unless defined $argref->{$param};
    }

    my $section    = "Database_$argref->{name}";

    if (not config_section_exists($section)) {
        croak("Unable to determine database connection parameters for $argref->{name}: No [$section] entry in config file");
    }

    # fill the easy params
    my %connect_params = (
        db_type => config_var($section, 'db_type'),
        db_name => config_var($section, 'db_name'),
        db_host => config_var($section, 'db_host'),
        compress => config_var($section, 'compress')||undef,
        connect_object => $argref->{connect_object},
        mysql_write_timeout   => config_var($section, 'mysql_write_timeout')   || undef,
        mysql_read_timeout    => config_var($section, 'mysql_read_timeout')    || undef,
        mysql_connect_timeout => config_var($section, 'mysql_connect_timeout') || undef,
    );

    # warn about AutoCommit being used in xtracker.conf
    # (as we don't actually pay any attention to it)
    if (defined config_var($section, 'AutoCommit')) {
        xt_logger->warn( "$section: AutoCommit setting found. This is IGNORED and should be removed." );
    }

    {
    # HACK: A horrible hack so we can use the 'autocommit' parameter in our
    # callers - but config lookups still use 'readonly' and 'transaction'
    # suffixes to determine user/pass
    my $type = $argref->{autocommit} ? 'readonly' : 'transaction';
    $connect_params{db_user} = config_var( $section, "db_user_$type" );
    $connect_params{db_pass} = config_var( $section, "db_pass_$type" );
    }

    # Only set a connect_object if we haven't passed it in our arguments (see
    # XTracker::BuildConstants for a use case)
    unless ( $connect_params{connect_object} ) {
        # what are we connecting with? defaults to "DBI", but could be DBIx::Class
        # schemas (e.g. XTracker::Schema)
        $connect_params{connect_object}
            = config_var($section, 'connect_object') // 'DBI';

        {
        # HACK: Until we deprecate xtracker's transaction (autocommit off)
        # handlers, we force these connections to use DBI connections so DBIC
        # doesn't warn
        $connect_params{connect_object} = 'DBI'
            if $argref->{name} eq 'xtracker' && !$argref->{autocommit};
        }
    }

    require_module($connect_params{connect_object})
        or croak "Couldn't require $connect_params{connect_object}: $@";

    $connect_params{attribs} = {
        PrintError => config_var($section, 'PrintError'),
        RaiseError => config_var($section, 'RaiseError'),
        AutoCommit => $argref->{autocommit} ? 1 : 0,
    };

    return \%connect_params;
}

=head2 xtracker_schema_no_singleton

We begrudgingly have to include this for now, but please don't use it unless
you really know what you're doing. Also make sure you clean up this dbh when
you're done with it.

=cut

sub xtracker_schema_no_singleton {
    db_connection({name => 'xtracker', autocommit => 1});
}

# We want to have two singletons - one for autocommit on (DBIC friendly, so we
# store the schema) and one for autocommit off (we want to discourage its use
# with DBIC - let's store the dbh itself).

{
my $XTRACKER_SCHEMA;

=head2 xtracker_schema() : XTracker::Schema

Returns the xtracker_schema singleton.

=cut

sub xtracker_schema :Export(:common) {
    $XTRACKER_SCHEMA ||= db_connection({
        name => 'xtracker', autocommit => 1,
    });
}

=head2 has_xtracker_schema() : Bool

Returns a true value if the xtracker schema singleton is set

=cut

sub has_xtracker_schema :Export(:common) { !!$XTRACKER_SCHEMA; }

=head2 clear_xtracker_schema

Clear and disconnect the xtracker_schema singleton.

=cut

sub clear_xtracker_schema :Export(:common) {
    $XTRACKER_SCHEMA->storage->disconnect
        if has_xtracker_schema() && $XTRACKER_SCHEMA->storage->connected;
    $XTRACKER_SCHEMA = undef;
}
}

{
my $XTRACKER_DBH_NO_AUTOCOMMIT;

=head2 xtracker_dbh_no_autocommit() : $dbh

Returns the xtracker no autocommit singleton dbh.

=cut

sub xtracker_dbh_no_autocommit {
    $XTRACKER_DBH_NO_AUTOCOMMIT ||= db_connection({
        name => 'xtracker', autocommit => 0,
    });
}

=head2 clear_xtracker_dbh_no_autocommit()

Clear and disconnect the xtracker no autocommit singleton dbh.

=cut

sub clear_xtracker_dbh_no_autocommit {
    $XTRACKER_DBH_NO_AUTOCOMMIT->disconnect if $XTRACKER_DBH_NO_AUTOCOMMIT;
    $XTRACKER_DBH_NO_AUTOCOMMIT = undef;
}
}

=head2 get_database_handle({ :$name!, :$type! }) : $schema | $dbh

This method is basically a fucking mess. For an xtracker db connection please
use the provided methods, and for any other dbhs please use L<db_connection>
directly. We should probably deprecate this soon (I'll write a ticket).

=cut

sub get_database_handle :Export(:common) {
    my ($argref) = @_;

    # make sure $argref really is a ref!
    if ('HASH' ne ref($argref)) {
        croak(q{You must pass a hash-reference to get_database_handle()});
    }
    # make sure that we've been told where we'd like to connect to
    if (not defined $argref->{name}) {
        croak(q{'name' must be passed in \%argref to get_database_handle()});
    }

    # anything ending in _schema *or* _schema_SOMETHING is considered to
    # be a DBIC schema that no longer requires a type
    # e.g. <Database_pws_schema_Intl> in xtracker_DB_XTDC1.conf
    my $want_dbic = $argref->{name} =~ m{^\w+_schema(?:_.+)?$};

    if ( exists $argref->{type} ) {
        cluck q{Don't pass 'type' if you want a schema object back}
            if $want_dbic;
        confess q{'type' is an optional argument, but when passed it must be 'readonly' or 'transaction'}
            unless $argref->{type} =~ m{^(?:readonly|transaction)$};
    }
    # We always assume autocommit on unless we explicitly pass a type of
    # 'transaction'
    my $is_autocommit = !($argref->{type} && $argref->{type} eq 'transaction');

    cluck q{Attempted to get a schema handle with autocommit off. Note that DBIC doesn't like this, please don't do it}
        if $want_dbic && !$is_autocommit;

    # HACK: 'Upgrade' xtracker_schema to xtracker so they share the same config
    # and we can share our singleton appropriately.
    $argref->{name} =~ s{^xtracker_schema$}{xtracker};

    # If we want a connection to xtracker we return a singleton
    if ( $argref->{name} eq 'xtracker' ) {
        if ( $is_autocommit ) {
            return $want_dbic ? xtracker_schema() : xtracker_schema()->storage->dbh;
        }
        else {
            return xtracker_dbh_no_autocommit();
        }
    }

    # We only get here if we want a non-xtracker connection...
    my $connection = db_connection({
        name => $argref->{name}, autocommit => $is_autocommit,
    });

    # did we actually get something defined back
    if (not defined $connection) {
        cluck $DBI::errstr;
        cluck(q{db_connection() returned an undefined value for name=} . $argref->{name});
    }

    # if it's a web db and webdbh logging is enabled - enable logging!
    if (config_var('Debugging', 'webdbh_logging')
        && $argref->{name} =~ /^Web_/) {
        open my $fh, '>:via(CustomLogger)', CustomLogger->new();

        $connection->trace('SQL', $fh);
    }

    return $connection;
}

=head2 get_schema_using_dbh( $dbh, $section ) : DBIx::Class::Schema

This gets a DBiC schema connection using a DBI connection that has already been
connected.

*** NOTE ***

If you use the $schema with a DBI connection with
AutoCommit set to 0 (off) then make sure you commit & rollback yourself when
using 'txn_do' as AutoCommit will be zero (off) when being used in transaction
mode and your changes won't be stored unless you do.

=cut

sub get_schema_using_dbh :Export(:common) {
    my $dbh     = shift;
    my $section = shift;

    # Return our singleton if we are passed its dbh
    return xtracker_schema()
        if has_xtracker_schema() && $dbh eq xtracker_schema()->storage->dbh;

    # The AutoCommit flag is turned off by DBIC when you're in a transaction,
    # so we don't check the flag for the xtracker schema singleton in case this
    # method is being called from within a transaction
    cluck "You have tried to get a schema for a dbh with autocommit turned off - please don't do this, it 'breaks' DBIC transactions"
        if !$dbh->{AutoCommit};

    # We have merged the xtracker_schema and xtracker config sections, so make
    # sure we pick up the 'xtracker' instead of 'xtracker_schema''s config
    # section
    $section =~ s{^xtracker_schema$}{xtracker};

    # get the DBiC object for the 'xtracker_schema' db connection from the conf file
    my $connect_object  = config_var('Database_'.$section, 'connect_object');

    # make sure the object is loaded
    require_module $connect_object
        or croak "Could not require $connect_object: $@";

    # pass in the DBI connection that has already been made and return the
    # appropriate DBIx::Class::Schema object
    return $connect_object->connect( sub { return $dbh } );
}

=head2 get_schema_and_ro_dbh( $conf_section ) : DBIx::Class::Schema, $dbh

This will return a connection (schema) to a database through DBiC and also that
schema's DBI handler with AutoCommit set to 1 (on) this can then be used as a
normal DBI handler.  Section in Conf file with Connection Details for using
DBiC.

=cut

sub get_schema_and_ro_dbh :Export(:common) {
    my $conf_section    = shift;

    # Nasty little hack, sorry
    if ( $conf_section =~ m{^(?:xtracker|xtracker_schema)$} ) {
        return ( map { $_, $_->storage->dbh } xtracker_schema() );
    }

    # Make the connection to DBiC
    my $schema = db_connection({name => $conf_section, autocommit => 1});

    # Do we need this line? I'm not sure...
    $schema->storage->ensure_connected;

    # get the DBI handler out of the DBiC connection
    my $dbh = $schema->storage->dbh;

    return ( $schema, $dbh );
}

=head2 read_handle

Get a database handle with autocommit = 1.

=cut

sub read_handle :Export(:common :DEFAULT) {
    return xtracker_schema()->storage->dbh;
}

=head2 transaction_handle

Get a database handle with autocommit = 0.

=head3 NOTE

Avoid if you'll be using this to get a DBIC schema object.

=cut

sub transaction_handle :Export(:common :DEFAULT) {
    return xtracker_dbh_no_autocommit();
}

=head2 schema_handle

An alias for L<xtracker_schema>, try and use that instead and we'll delete sub.

=cut

sub schema_handle :Export(:common :DEFAULT) {
    return xtracker_schema();
}

# this has been deprecated for literally years now
sub fcp_staging_handle :Export(:DEFAULT) {
    carp(q{DEPRECATED: fcp_staging_handle() is no longer a supported XTracker::Database method});

    return db_connection({ name => 'Web_Staging', autocommit => 0 });
}

1;
