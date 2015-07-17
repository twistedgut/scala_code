package Test::XT::Prove::Role::DateTime::Manipulate;

use Moose::Role;

use Data::Dump qw/pp/;

with 'XTracker::Role::WithSchema';

sub manipulate_now_time {
    my($self,$desc,$now) = @_;

    $now //= $self->schema->db_now;

    return $now if (!defined $desc);

    foreach my $key (keys %{$desc}) {
        eval {
            $now = $now->$key( %{$desc->{$key}} );
        };
        if (my $e = $@) {
            die "Cannot called $key with ". pp($desc->{$key}) ." on DateTime";
        }

    }
    return $now;
}


1;
