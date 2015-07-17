package NAP::XT::Exception::MissingRequiredParameters;
use NAP::policy qw/exception/;

=head1 NAME

NAP::XT::Exception::MissingRequiredParameters

=head1 DESCRIPTION

Error thrown if required parameters have not been passed to a method

=cut

has 'missing_parameters' => (
    is  => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
);

has '+message' => (
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $missing_parameters = join(', ', @{$self->missing_parameters()});
        my $only_got_1 = (@{$self->missing_parameters()} == 1 ? 1 : 0);
        return sprintf('The required parameter%s "%s" %s missing',
            ($only_got_1 == 1 ? '' : 's'),
            $missing_parameters,
            ($only_got_1 == 1 ? 'is' : 'are')
        );
    },
);
