package DBIx::Class::RowRestore;
use Moose;

=head1 NAME

DBIx::Class::RowRestore - Restore rows

=head1 DESCRIPTION

Temporarily change row data (e.g. for a test), and have it
automatically restored when the guard variable goes out of scope.

Note: This is a naive implementation of scoped guard functionality,
but subclassing or using other Guard classes turned out to require
more cleverness than I could muster. Doing it right would involve
dealing with exceptions/evals, and localizing various globals.

=head1 SYNOPSIS

    use DBIx::Class::RowRestore;
    use Guard;
    {
        my $row_restore = DBIx::Class::RowRestore->new();
        my $row_guard = guard { $row_restore->restore_rows };

        my $product = $product_rs->find($id);
        $row_restore->add_to_update( $product );
        # Now it's safe to ->update $product for the test fixtures

        $product->update({ note => "OHAI" });
    }
    # Here $product->note is restored

    # Shorter version
    {
        my $row_restore = DBIx::Class::RowRestore->new();
        my $row_guard = guard { $row_restore->restore_rows };
        $product_rs->find($id);
        $row_guard->add_to_update( $product, { note => "OHAI" } );
    }

Feel free to add support for deleting added rows, etc. as needed.

=cut

use DBIx::Class;

has to_update => (is => "rw", isa => "ArrayRef", default => sub { [] });

no Moose;

sub add_to_update {
    my ($self, $row, $update_col_value) = @_;

    push(@{$self->to_update}, {
        row    => $row,
        values => { $row->get_columns },
    });

    $update_col_value and $row->update($update_col_value);

    return $self->to_update;
}

sub restore_rows {
    my $self = shift;

    for my $to_restore (@{$self->to_update}) {
        my ( $row, $values ) = @{$to_restore}{qw/row values/};

        for my $col ( keys %$values ) {
            $row->set_column($col => $values->{$col});
            $row->make_column_dirty($col);
        }
        $row->update;
        $row->discard_changes;
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
