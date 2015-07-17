#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use lib 't/lib/';
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use List::MoreUtils qw(uniq);
use File::Temp qw( tempfile );
use Getopt::Long::Descriptive;
use Carp qw(croak);

use Test::XT::BlankDB;
use XTracker::BuildConstants;
use XTracker::Schema;

my ($opt, $usage) = describe_options(
    'create_blank_db.pl %o',
    [ 'source|s=s', "Name of reference DB", { required => 1 } ],
    [ 'source_host|S=s', "Hostname of reference DB", { default => 'localhost' } ],
    [ 'target|t=s', "Name of output DB (will be wiped)", { required => 1 } ],
    [ 'target_host|T=s', "Hostname of output DB (will be wiped)", { default  => 'localhost' } ],
    [ 'delete_temp_files|d=s', "Temp files will be deleted", { default  => 1 } ],

    [],
    [ 'help',       "print usage message and exit" ],
);

print($usage->text), exit if $opt->help;

my $unlink_temp_files = $opt->{delete_temp_files};
my $temp_file_prefix = time();

my $pg_dump_fqpn = '/usr/pgsql-9.0/bin/pg_dump';
my $psql_fqpn = '/usr/pgsql-9.0/bin/psql';
#
# FIRST: Create a list of our table names
#
my @tables = map { "-t $_" } Test::XT::BlankDB::reference_tables;

#
# SECOND: Dump the schema of the source DB
#
my ($schema_fh, $schema_filename) = tempfile(
    "$temp_file_prefix-pg_schema_dumpXXXXX",
    DIR    => "tmp",
    UNLINK => $unlink_temp_files,
);
execute(
    "Dumping schema to $schema_filename",
    $pg_dump_fqpn =>
        '--schema-only', '-Upostgres', '-f' . $schema_filename, $opt->{'source'}, '-h' . $opt->{'source_host'} );
close $schema_fh;

{
# fixing the export:
# - forcing constraint deferral
# - granting all to www
rename($schema_filename,"${schema_filename}.bak");
open my $src, '<', "${schema_filename}.bak";
open my $dst, '>', $schema_filename;
my %grants;my $current_schema;
while (my $line = <$src>) {

    if ($line =~ m/SET search_path (?:=|TO) (\w+)/) {
        $current_schema = $1;
    }
    elsif ($line =~ m/\bFOREIGN KEY\b/i) {
        $line =~ s/^(\s*ADD CONSTRAINT\b.+)(?<!DEFERRABLE);$/$1 DEFERRABLE;/gi
    }
    elsif ($line =~ m/\bGRANT ALL ON (\w+ \w+) TO (\w+)/) {
        if ($2 eq 'postgres') {
            $grants{$current_schema}{$1}++;
        }
        elsif ($2 eq 'www') {
            $grants{$current_schema}{$1}--;
        }
    }
    print {$dst} $line;
}

while (my ($schema,$grants) = each %grants) {
    print {$dst} "SET search_path = $schema, pg_catalog;\n";
    while (my ($grant,$needed) = each %$grants) {
        next unless $needed;
        print {$dst} "GRANT ALL ON $grant TO www;\n";
    }
}
close $src;close $dst;
}

#
# THIRD: Wipe then recreate the target db
#
execute(
    sprintf("Wiping the target db: %s@%s",$opt->{'target'},$opt->{'target_host'}),
    $psql_fqpn =>
        '-Upostgres', '-h' . $opt->{'target_host'},
        '-c DROP DATABASE IF EXISTS ' . $opt->{'target'} . '' );
execute(
    sprintf("Recreating the target db: %s@%s",$opt->{'target'},$opt->{'target_host'}),
    $psql_fqpn =>
        '-Upostgres','-h' . $opt->{'target_host'},
        '-c CREATE DATABASE ' . $opt->{'target'} );

#
# FOURTH: Load in the blank schema
#
execute(
    "Loading up the blank schema",
    $psql_fqpn =>
        '-Upostgres', '-d' . $opt->{'target'}, '-h' . $opt->{'target_host'}, '-f' . $schema_filename
);

#
# FIFTH: Prep up our DB commands
#
my ($maintenance_fh, $maintenance_filename) = tempfile(
    "$temp_file_prefix-pg_data_dumpXXXXX",
    DIR    => "tmp",
    UNLINK => $unlink_temp_files,
);
print $maintenance_fh "BEGIN; SET CONSTRAINTS ALL DEFERRED;\n";

# Output the string to dump tables
my $table_string = join q{ }, sort @tables;
my $backticks_cmd = sprintf("$pg_dump_fqpn $table_string -Upostgres -h%s --data-only %s",$opt->{'source_host'},$opt->{'source'});
print "$backticks_cmd\n";
my $reference_data = `$backticks_cmd`; ## no critic(ProhibitBacktickOperators)
print length($reference_data) . " characters retrieved\n";
print $maintenance_fh $reference_data . "SET search_path to public;\n\nCOMMIT;\n";

# Add the superpowers script
print $maintenance_fh <<'END';

-- Useful to have this kicking around...
-- http://confluence.net-a-porter.com/display/BAK/XTDC+and+Fulcrum+Dev+Deployment

BEGIN;
create or replace function superpowers(uname varchar,email varchar,autologin integer) returns void as $$
    BEGIN
       update operator set auto_login=autologin where username=uname;
       update operator set disabled=0 where username=uname;
       update operator set email_address=email where username=uname;

       delete from operator_authorisation where operator_id=(select id from operator where username=uname);

       insert into operator_authorisation (operator_id,authorisation_sub_section_id,authorisation_level_id) select (select id from operator where username=uname),id, (select id from authorisation_level where description='Manager') from authorisation_sub_section;
   END;
$$ language plpgsql;
COMMIT;

END

close $maintenance_fh;

#
# SIXTH: Execute!
#
execute(
    "Installing reference data in to " . $opt->{'target'},
    $psql_fqpn => '-Upostgres', '-d' . $opt->{'target'}, '-h' . $opt->{'target_host'}, '-f' . $maintenance_filename
);

#
# SEVENTH: Add our 'fixtures'
#
my $source=get_schema($opt->{source},$opt->{source_host});
my $target=get_schema($opt->{target},$opt->{target_host});
$target->txn_do( sub {
    Test::XT::BlankDB::create_fixtures( $source, $target );
});

# utilitiy subs
sub execute {
    my ($sys_name, @commands) = @_;
    print STDERR $sys_name . "\n";
    print STDERR (join ' ', @commands) . "\n";
    system( @commands ) == 0 or croak "system " . (join ' ', @commands) . " failed: $?";
    print STDERR "Success\n";
}

sub get_schema {
    my ($db,$host)=@_;

    return XTracker::Schema->connect(
        "dbi:Pg:dbname=$db;host=$host",
        'postgres','',
        {
            AutoCommit => 1,
            PrintError => 0,
            RaiseError => 1,
        },
    );
}

__END__
dropdb xt_test;
createdb xt_test;
pg_dump --schema-only -Upostgres -f ~/xt_test.sql xtracker
psql -Upostgres -d xt_test -f ~/xt_test.sql



paste output from code above - creates constants_data.sql

psql
SET search_path to public;
\i db_schema/2010.27/Common/01_deferrable_fk.sql
BEGIN; SET CONSTRAINTS ALL DEFERRED;
ALTER TABLE correspondence_templates DROP CONSTRAINT correspondence_templates_department_id_fkey, ADD FOREIGN KEY (department_id) REFERENCES department(id) DEFERRABLE;
ALTER TABLE customer_issue_type DROP CONSTRAINT customer_issue_type_issue_type_group_id_fkey, ADD FOREIGN KEY (group_id) REFERENCES customer_issue_type_group(id) DEFERRABLE;
ALTER TABLE segment DROP CONSTRAINT segment_segment_type_id_fkey, ADD FOREIGN KEY (segment_type_id) REFERENCES segment_type(id) DEFERRABLE;
\i constants_data.sql
insert into designer VALUES (1, 'Rows', 'Rows');

ROLLBACK;
