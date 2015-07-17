#!/opt/xt/xt-perl/bin/perl

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

=head1 NAME

script/prl/migration/cage_storage_type.pl

=head1 DESCRIPTION

Script to deal with products that are stored in the cage, but have the
wrong storage type.

This script works in three modes, you can display either a count of the
product or a full list of the product/variant deals. Finally, you can fix
the incorrect storage type records.

=head1 SYNOPSIS

    perl cage_storage_type.pl [--list|--count|--fix]

=head2 OPTIONS

=head2 --list

List details about the products and variants with the incorrect storage type.
This is the default action.

=head2 --count

Just display a count of the products/variants with the incorrect storage type.

=head2 --fix

Fix the products that have the incorrect storage type.

=cut

use Getopt::Long;
use Pod::Usage;
use Text::ANSITable;

use XTracker::Database qw/get_database_handle/;
use XTracker::Constants::FromDB ':storage_type';

# default behaviour
@ARGV = ('--list') if ! @ARGV; ## no critic(RequireLocalizedPunctuationVars)

my %opt;
my $result = GetOptions( \%opt,
    'help|h|?',
    'list',
    'count',
    'fix',
);

die "Only one option at a time\n" if keys %opt > 1;

pod2usage(1) if $opt{help};

my ($mode) = keys %opt;

my $dbh = get_database_handle({ name => 'xtracker' });

# See http://jira4.nap/browse/DCA-2358 for the SQL
my $from_where = qq[
from quantity q
join flow.status s on q.status_id = s.id
join location l on q.location_id = l.id
join variant v on q.variant_id = v.id
join product p on v.product_id = p.id
join classification c on p.classification_id = c.id
join product.storage_type st ON p.storage_type_id = st.id
where p.storage_type_id != $PRODUCT_STORAGE_TYPE__CAGE
and (l.location like '02_Y%'
OR l.location like '02_B%')
and q.quantity > 0
];

my %sql = (
    count => {
        sql                => qq[select count(*) $from_where],
        show_result_table  => 1,
        show_affected_rows => 0,
    },
    list  => {
        sql                => qq[select distinct(v.id),
                              v.product_id || '-' || sku_padding(v.size_id)
                                as sku,
                              c.classification,
                              l.location,
                              st.name
                              $from_where
                              order by v.id],
        show_result_table  => 1,
        show_affected_rows => 1,
    },
    fix   => {
        sql                => qq[update product
                              set storage_type_id = $PRODUCT_STORAGE_TYPE__CAGE
                              where id in
                              (select distinct(p.id)
                              $from_where)],
        show_result_table  => 0,
        show_affected_rows => 1,
    },
);

my $sql = $sql{$mode}{sql};
my $sth = $dbh->prepare($sql);
$sth->execute;

if ($sql{$mode}{show_result_table}) {
    my $table = Text::ANSITable->new(use_utf8 => 0);
    $table->columns($sth->{NAME});
    $table->add_row_separator;

    while (my $row = $sth->fetch) {
         $table->add_row($row);
    }
    say $table->draw;
}

if ($sql{$mode}{show_affected_rows}) {
    say $sth->rows, ' row(s) affected.';
}
