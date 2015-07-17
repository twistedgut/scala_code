package XTracker::Database::Note;

use strict;
use warnings;
use Carp qw/croak/;

use Perl6::Export::Attrs;
use XTracker::Database::Utilities qw( last_insert_id );
use XTracker::Database qw( get_schema_using_dbh );
use XTracker::DBEncode qw( decode_db );

my %_table_mappings = (
    Order       => "order_note",
    Return      => "return_note",
    Shipment    => "shipment_note",
    Customer    => "customer_note",
    PreOrder    => "pre_order_note",
    'Quality Control' => "shipment_note"
);
sub _lookup_table_name {
    my $category   = shift;
    my $table_name = $_table_mappings{ $category };
    croak "Could not match table name to note category: $category"
        unless $table_name;
    return $table_name;
}

my %_resultset_mappings = (
    Order       => 'Public::OrderNote',
    Return      => 'Public::ReturnNote',
    Shipment    => 'Public::ShipmentNote',
    Customer    => 'Public::CustomerNote',
    PreOrder    => 'Public::PreOrderNote',
    'Quality Control' => 'Public::ShipmentNote',
);
sub _lookup_resultset_name {
    my $category = shift;
    my $resultset_name = $_resultset_mappings{ $category };
    croak "Could not match resultset name to note category: $category"
        unless $resultset_name;
    return $resultset_name;
}

sub create_note :Export() {
    my ( $dbh, $argref ) = @_;
    my $note_id = 0;

    my $table_name = _lookup_table_name( $argref->{note_category} );

    my $qry = 'INSERT INTO '.$table_name.' VALUES (default, ?, ?, ?, ?, current_timestamp)';
    my $sth = $dbh->prepare($qry);
    $sth->execute($argref->{category_id}, $argref->{note}, $argref->{type_id}, $argref->{operator_id});

    $note_id = last_insert_id( $dbh, $table_name.'_id_seq' );

    return $note_id;
}

sub update_note :Export() {
    my ( $dbh, $argref ) = @_;
    my $resultset_name = _lookup_resultset_name( $argref->{note_category} );

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    $schema->resultset( $resultset_name )->find( $argref->{note_id} )->update({
            note => $argref->{note},
            note_type_id => $argref->{type_id},
        });

    return;
}

sub delete_note :Export() {
    my ( $dbh, $argref ) = @_;
    my $table_name = _lookup_table_name( $argref->{note_category} );

    my $qry = "DELETE FROM ".$table_name." WHERE id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($argref->{note_id});

    return;

}

sub get_note :Export() {
    my ( $dbh, $note_type, $note_id ) = @_;
    my $table_name = _lookup_table_name( $note_type );

    my $qry = 'SELECT n.note, n.date, n.note_type_id, nt.code, nt.description, op.name
                FROM '.$table_name.' n, note_type nt, operator op
                WHERE n.id = ?
                AND n.note_type_id = nt.id
                AND n.operator_id = op.id';

    my $sth = $dbh->prepare($qry);
    $sth->execute($note_id);

    my $data = $sth->fetchrow_hashref() || return;
    $data->{$_} = decode_db( $data->{$_} ) for (qw( note ));

    return $data;
}

sub get_note_types :Export() {
    my ( $dbh ) = @_;

    my $qry = "SELECT * FROM note_type";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{id} } = $row;
    }
    return \%data;
}

1;
