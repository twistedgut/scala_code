#!perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use XTracker::Constants      qw($APPLICATION_OPERATOR_ID);
use XTracker::Database::Note qw( create_note
                                 get_note
                                 update_note
                                 delete_note );

=head1 Pre-Order Note Tests

    Test the database interaction using the general note functions in
    XTracker::Database::Note

=cut

my $dbh          = Test::XTracker::Data->get_dbh;
my $schema       = Test::XTracker::Data->get_schema;
my $pre_order    = Test::XTracker::Data::PreOrder->create_complete_pre_order();
my $note_type_id = $schema->resultset('Public::PreOrderNoteType')->first->id;

my $note_id
  = create_note( $dbh,
                 { note_category => 'PreOrder',
                   category_id   => $pre_order->id,
                   note          => 'Testing Notes',
                   type_id       => $note_type_id,
                   operator_id   => $APPLICATION_OPERATOR_ID,
                 });

my $note = get_note( $dbh, 'PreOrder', $note_id);

ok(ref $note eq 'HASH', 'Pre-order note data');
cmp_ok($note->{note}, 'eq', 'Testing Notes', 'Pre-order note string');

update_note( $dbh, { note_category => 'PreOrder',
                     type_id       => $schema->resultset('Public::PreOrderNoteType')->first->id,
                     note          => 'Change the notes',
                     note_id       => $note_id });

my $new_note = get_note( $dbh, 'PreOrder', $note_id);

cmp_ok($new_note->{note}, 'eq', 'Change the notes', 'Pre-order note updated');

delete_note( $dbh, { note_category => 'PreOrder',
                     note_id       => $note_id } );

my $no_note = get_note( $dbh, 'PreOrder', $note_id);

is($no_note, undef, 'Pre-order note deleted');

done_testing;
