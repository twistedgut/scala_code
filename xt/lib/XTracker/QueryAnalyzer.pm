package XTracker::QueryAnalyzer;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use DateTime;
use File::Temp qw/ tempfile tempdir /;
use Perl6::Export::Attrs;
use XTracker::Database qw ( :common );
use XTracker::Logfile qw(xt_logger);
use XTracker::Config::Local qw( config_var );

use Analysis::Schema;

sub store_analyzed_queries :Export {
    my ($handler, $analyzer) = @_;

    my $dbfile = config_var('SystemPaths','xtdc_base_dir').'/queries.db';

    my $schema =
    Analysis::Schema->connect("dbi:SQLite:$dbfile");
    my @queries = $analyzer->get_sorted_queries();

    eval {
        foreach my $query_block (@queries) {
            # store the request
            my $request = $schema->resultset('Request')->create(
                {
                    timestamp       => DateTime->now( time_zone => "local" )->iso8601(),
                    the_request     => $handler->{request}->the_request(),
                    query_count     => scalar(@{ $query_block }),
                    object          => ref($handler->{schema}),
                }
            );

            foreach my $query (@{ $query_block }) {
                $schema->resultset('Query')->create(
                    {
                        request_id      => $request->id(),

                        time_elapsed    => $query->time_elapsed,
                        start_time      => $query->start_time,
                        end_time        => $query->end_time,
                        sql             => $query->sql,
                        sql_params      => join(q{,}, @{$query->params}),
                    }
                );
            }
        }
    };
    if ($@) {
        xt_logger->warn(qq{Errors occurred whilst trying to store the query information. Usually this is because $dbfile is missing or the directory has incorrect permissions. "perldoc ./lib/XTracker/QueryAnalyzer.pm" for instructions});
        xt_logger->debug($@);
    }

    return;
}

# yeah, it's evil, but it's quick and evil
# now that we're storing results in sqlite, we ought to use that to generate
# HTML reports...
sub dump_sorted :Export {
    my ($analyzer) = @_;

    if (! -d '/tmp/query_analysis/') {
        mkdir ('/tmp/query_analysis/') or die $!;
    }

    my $tmpfile = File::Temp->new(
        TEMPLATE    => 'sorted_XXXXXXXX',
        DIR         => '/tmp/query_analysis',
        SUFFIX      => '.html',
        UNLINK      => 0,
    ) or die $!;

    print $tmpfile q{
    <html>
    <head>
    <title>XTracker Query Dump</title>
    <style type="text/css" media="screen">@import "http://xtracker.net-a-porter.com/css/xtracker.css";</style>
    <style type="text/css" media="screen">@import "http://xtracker.net-a-porter.com/css/xtracker_static.css";</style>
    </head>
    <body>
    };

    my @queries = $analyzer->get_sorted_queries();

    foreach my $query_block (@queries) {
        print $tmpfile
            q{<p>}
            . scalar(@{ $query_block })
            . q{ queries run}
            . "\n"
            . q{</p>}
        ;
        xt_logger->debug(
            scalar(@{ $query_block })
            . q{ queries run}
        );

        print $tmpfile q{
            <table border="1">
            <thead>
            <td>Elapsed</td>
            <td>Start</td>
            <td>End</td>
            <td>SQL</td>
            </thead>
            <tbody>
        };
        foreach my $query (@{ $query_block }) {
            print $tmpfile q{
                <tr style="vertical-align:top;">
            };

            print $tmpfile
                  q{<td>}
                . $query->time_elapsed
                . q{</td>}
            ;
            print $tmpfile
                  q{<td>}
                . $query->start_time
                . q{</td>}
            ;
            print $tmpfile
                  q{<td>}
                . $query->end_time
                . q{</td>}
            ;
            print $tmpfile
                  q{<td>}
                . $query->sql
                . q{</td>}
            ;

            print $tmpfile q{
                </tr>
            };
        }
        print $tmpfile q{
            </tbody>
            </table>
        };
    }

    print $tmpfile q{
    </body></html>
    };
    $tmpfile->close;

    return;
}

1;

__END__

=pod

=head1 NAME

XTracker::QueryAnalyzer - some useful stuff for analyzing DBIC queries

=head1 CONFIGURATION

=head2 CREATE THE DATABASE

Assuming it doesn't already exist, the following incantation will create an
empty database:

    echo "
    CREATE TABLE request (
        id              INTEGER PRIMARY KEY,

        timestamp       NONE,
        the_request     TEXT,
        query_count     INTEGER,
        object          TEXT
    );


    CREATE TABLE query (
        id              INTEGER PRIMARY KEY,
        request_id      INTEGER,

        time_elapsed    REAL,
        start_time      REAL,
        end_time        REAL,

        sql             TEXT,
        sql_params      TEXT
    );
    " |sqlite3 $xtdc_base_dir/queries.db

=head2 PERMISSIONS

SQLite needs write access to the directory containing the DB file because it
creates another file "dbfilename-journal" when a transaction is started.

Because of this, we need to make sure the application can write to the
directory containing queries.db:

  sudo chgrp www-data $xtdc_base_dir/queries.db
  sudo chmod g+w $xtdc_base_dir/queries.db
  sudo chgrp www-data $xtdc_base_dir
  sudo chmod g+w $xtdc_base_dir

Depending on your system, you may need to replace I<www-data> with the
groupname used in your apache configuration.

=head2 ENABLING ANALYZING

Edit C</etc/xtracker/xtracker.conf> and create or extend the [Debugging]
section to include I<query_analysis>:

  [Debugging]
  sessions=0
  query_analysis=1

=head1 GETTING INFORMATION OUT OF SQLITE

A quick and dirty way to get information out of the sqlite database is:

  sqlite3 $xtdc_base_dir/queries.db "SELECT * FROM query"

and

  sqlite3 $xtdc_base_dir/queries.db "SELECT * FROM request"

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut
