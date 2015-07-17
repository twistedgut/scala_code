package Test::AssertRecords::PluginBase;
use Moose::Role;
use File::Temp qw/ tempfile /;
use File::Copy;
use Test::More 0.98;
use Test::Differences;
use Data::Dump qw/pp/;
use JSON;

#requires (qw/map/);
has map => (
    is => 'ro',
    default => sub {
        return undef;
    },
);



sub test_assert_mapping {
    my($self,$class,$schema,$test_cases) = @_;

    if (!$self->can('map') || !defined $self->map) {
        diag "No mapping for test cases to DBIx";
        return;
    }

    foreach my $test_case (@{$test_cases}) {
        my $rs = $self->find_base_record($schema->resultset($class),$test_case);

        is($rs->count,1,'found 1 and only 1 match')
        || note " expected: ". pp($test_case);

        # no point if it can't find it/know which one it is
        next if ($rs->count != 1);

        my $rec = $rs->first;
        my $from_db = $self->resolve($rec);

        $self->compare_test($from_db,$test_case);
    }
}

# a simple default
sub find_base_record {
    my($self,$rs,$test_case) = @_;

    return $rs->search($self->local_fields($test_case));
}

sub compare_test {
    my($self,$got,$expected) = @_;

    foreach my $field (keys %{$self->map}) {
        next if (!exists $expected->{$field});
        is($got->{$field},$expected->{$field},
            "field matched ($field)")
        || note " got: ". pp($got) ."\n expected: ". pp($expected);
    }
}

sub local_fields {
    my($self,$test_case) = @_;
    my $map = $self->map;

    my @local_fields = grep {
        exists $map->{$_} && !defined $map->{$_}
    } keys %{$map};

    my $local;
    foreach my $field (@local_fields) {
        $local->{$field} = $test_case->{$field};
    }

    return $local;
}

sub resolve {
    my($self,$record) = @_;
    my $map = $self->map;

    return { } if (!defined $map || ref($map) ne 'HASH');

    my $resolve_rec;
    foreach my $field (sort keys %{$map}) {
        $resolve_rec->{$field} = $self->find_field($record,$field);
    }

    return $resolve_rec;
}

sub find_field {
    my($self,$start_rec,$key) = @_;
    my $map = $self->map;
    my $mapping = $map->{$key} || undef;

    my $record = $start_rec;
    return $record->$key if (!defined $mapping);

    foreach my $rel (@{$mapping}) {
        $record = $record->$rel;
    }
    return $record;
}

sub make_record {
    my($self,$row) = @_;
    return $self->resolve($row);
}

sub write_file {
    my($self,$rs,$file,$key) = @_;

    my $set = $rs->search();
    my @recs;
    foreach my $row ($set->all) {
        push @recs, $self->make_record($row);
    }


    my($fh,$filename) = tempfile();
    binmode($fh,":encoding(UTF-8)");
    note "FILE: $filename";


    print $fh to_json({
        $key => \@recs,
    },{ utf8 => 1, pretty => 1 });

    $fh->close;

    note "  moving to: $file";
    isnt(move($filename,$file),0,
        "moved file $filename to $file");

}



1;
