package CSV::Base;

use Moose::Role;
#use Parse::CSV;
use Text::CSV;

requires (qw/ parse_line /);

has result => (
    is => 'rw',
#    default
);

sub parse {
    my($self,$file) = @_;

    # make it understand about utf8
    open my $io, "<:encoding(utf8)", $file or die "$file: $!";

    my $parser = Text::CSV->new({
        binary => 1,
    });

    my $count;
    while (my $arr = $parser->getline($io)) {
        $count++;
        # make the mysql NULLs undef
        for my $i (0..$#{$arr}) {
            if ($arr->[$i] eq '\N') {
                $arr->[$i] = undef;
            }
        }
        $self->parse_line($arr);
    }

    $io->close;
    return $count;
}

1;
