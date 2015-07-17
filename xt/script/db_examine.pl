#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
our $VERSION = 1;

=head1 NAME

db_examine.pl - Parse the XTDC DB to text

=head1 DESCRIPTION

Renders as text tables from the XTDC DB, by parsing the information schema,
skipping tables listed in C<XTracker::BuildConstants::constant_data_list>.

=head1 AUTHOR

Gianni, hacked by lee

=cut

use DBI;
use Data::Dumper;

use lib '/home/lee/src/xt/lib';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::BuildConstants;

# Known tables of 'constants' used in Perl code
# - is a hash simply for easy look-up
my $Keep_Tables = {
    map { $ _->{table_name} => 1}  @XTracker::BuildConstants::constant_data_list
};

my $fn = "tables_ref_once.txt";
print "OUTPUT TO $fn\n";
open my $OUT, ">", $fn or die $!;

my $dbh=DBI->connect('dbi:Pg:dbname=xtracker_lee','postgres','');

my @Tables;

my $tables_sth = $dbh->table_info('%','%','%','TABLE');

$tables_sth->execute();
while (my $table=$tables_sth->fetchrow_hashref) {
    next if $table->{TABLE_SCHEM} eq 'information_schema';
    next if $table->{TABLE_SCHEM} eq 'pg_catalog';

    next if exists $Keep_Tables->{ $table->{TABLE_NAME} };

    printf "Table %s.%s\n",$table->{TABLE_SCHEM},$table->{TABLE_NAME};

    my $col_sth=$dbh->column_info(
        $table->{TABLE_CAT},
        $table->{TABLE_SCHEM},
        $table->{TABLE_NAME},
        '%',
    );
    $col_sth->execute();
    while (my $column=$col_sth->fetchrow_hashref) {
        printf "  % 20s % 20s\n",$column->{COLUMN_NAME},uc($column->{TYPE_NAME});
    }
    print "----------------\n";
    my $val_sth=$dbh->prepare(
        sprintf 'SELECT * FROM %s.%s LIMIT 10',
        $table->{TABLE_SCHEM},
        $table->{TABLE_NAME},
    );
    $val_sth->execute();

    my $rows=$val_sth->fetchall_arrayref;
    my @lengths;
    for my $row (@$rows) {
        for my $i (0..$#$row) {
            $lengths[$i]||=6;
            next unless defined $row->[$i];
            if ($lengths[$i] < length($row->[$i])) {
                $lengths[$i] = length($row->[$i]);
            }
            if ($lengths[$i] > 20) {
                $lengths[$i] = 20;
            }
        }
    }
    my $fmt=" | ".join('',map {" % ${_}s |"} @lengths)."\n";
    for my $row (@$rows) {
        printf $fmt,
            map { defined($_) ?
                      (length($_) > 20 ? substr($_,0,17)."..." : $_)
                  : '<NULL>' } @$row;
    }

# print "----------------\n";
# @_ = `grep -r $table->{TABLE_NAME} /home/lee/src/xt/lib`;
# print "Refs in xt/lib: ", scalar(@_),"\n";
# print "\t".$_[0]."\n" if $#_==0;
    print "----------------\n\n";


    print $OUT $table->{TABLE_NAME},"\n",$_[0],"\n\n" if $#_==0;


    if (
        my $fk_sth = $dbh->foreign_key_info( '%', $table->{TABLE_SCHEM}, $table->{TABLE_NAME}, undef, undef, undef)
    ) {
        $fk_sth->execute;
        while (my $row = $fk_sth->fetchrow_hashref) {

            printf "This %s.%s.%s <---- %s.%s.%s\n", map {$row->{$_}} qw(
                                                                            UK_TABLE_SCHEM UK_TABLE_NAME UK_COLUMN_NAME
                                                                            FK_TABLE_SCHEM FK_TABLE_NAME FK_COLUMN_NAME
                                                                    );

            # my $fk_table = $row->{FK_TABLE_NAME}.$row->{FK_TABLE_NAME};
            # my $fk_str = $row->{FK_TABLE_SCHEM}.".".$row->{FK_TABLE_NAME};
            # my $uk_str = $row->{UK_TABLE_SCHEM}.".".$row->{UK_TABLE_NAME};


        }
    }


}

close $OUT;

