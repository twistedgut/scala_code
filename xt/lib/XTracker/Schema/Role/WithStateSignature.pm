package XTracker::Schema::Role::WithStateSignature;
use Moose::Role;

sub columns_for_signature {
    my ($self) = @_;

    my %cols=$self->get_columns();
    my @cols=sort keys %cols;
    return @cols;
}

sub relationships_for_signature {
    return ();
}

sub state_signature {
    my ($self) = @_;

    my @cols = $self->columns_for_signature();
    my @rels = $self->relationships_for_signature();

    my $ret;
    for my $col (@cols) {
        my $val = $self->get_column($col);

        if (defined $val) {
            $val =~ s{"}{\\"}g;
            $val = qq{"$val"};
        }
        else {
            $val = 'undef';
        }
        $ret .= $val . ';';
    }

    for my $rel (@rels) {
        my $rs = $self->related_resultset($rel);
        my @pris = $rs->result_source->primary_columns;
        if (@pris) {
            $rs = $rs->search({},{
                order_by => { -asc => \@pris },
            });
        }
        $ret .= '(';
        while (my $rec = $rs->next) {
            $ret .= '(' . $rec->state_signature() . ');';
        }
        $ret .= ')';
    }

    return $ret;
}

1;
