#!/opt/xt/xt-perl/bin/perl

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

=head1 NAME

script/prl/migration/count_products_by_storage_type.pl

=head1 DESCRIPTION

Script to display a count of products in the database, and which storage type they are.

Default output with no parameters is to display a count of all product storage types,
if you specify a parameter, e.g. --type Dematic_Flat, it only counts products of that type.

=head1 SYNOPSIS

In terminal run following command:

    perl count_products_by_storage_type.pl \
        [ --type [Storage_Type] ]

All parameters in "[ ... ]" are optional.

Storage_Type must be one of the storage types in the database, e.g. Dematic_Flat
or Flat (must be correct case)

=cut

use Getopt::Long;
use Pod::Usage;

use XTracker::Database qw/schema_handle/;

my %opt;
my $result = GetOptions( \%opt,
    'help|h|?',
    'type=s',
);

pod2usage(1) if (!$result || $opt{help});

my $schema = schema_handle();

my @storage_types = $schema->resultset('Product::StorageType')->all;
my @all_storage_types = map { $_->name } @storage_types;

my $storage_type_summary = '
SELECT st.name AS storage_type, count(*) AS count
FROM product p
JOIN product.storage_type st ON (p.storage_type_id = st.id)
GROUP BY p.storage_type_id, st.name';

if (defined $opt{type}) {
    @storage_types = grep { $_->name eq $opt{type} } @storage_types;
    if (scalar(@storage_types) == 0) {
        print "Did not recognise storage type '".$opt{type}."', must be one of:\n";
        print "- $_\n" foreach @all_storage_types;
        exit 1;
    }
    $storage_type_summary .= " having name = '".$opt{type}."'"; # validated
}

my $storage_types_count = $schema->storage->dbh->selectall_hashref($storage_type_summary, "storage_type");

print "Count of products with storage types:\n\n";
foreach my $storage_type (@storage_types) {
    print dots_justify( $storage_type->name, ($storage_types_count->{ $storage_type->name }->{count} // 0) ) . "\n";
}
print "\n";

sub dots_justify {
    my ($text, $count) = @_;
    my $line_length = 25;
    return $text . ('.' x ( $line_length - length($text) - length($count) )) . $count;
}
