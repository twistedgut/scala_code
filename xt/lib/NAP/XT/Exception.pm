package NAP::XT::Exception;

=head1 NAME

NAP::XT::Exception - General XT exception

=head1 DESCRIPTION

Exception to be thrown if none of the more specific exceptions apply

=head1 SYNPOSIS

    # in web application
    $c->log->logdie(
        NAP::XT::Exception->new({
            error => 'description',
        })
    );

OR

    NAP::XT::Exception->throw({
        error => 'description',
    })

=cut

use NAP::policy "tt", 'exception';

=head1 Attributes

As NAP::Exception

=cut

has 'error' => (
    is       => 'ro',
    required => 1,
);

has '+message' => (
    default => '%{error}s',
);

=head1 SEE ALSO

B<NAP::Exception> (in NAP-POLICY)

=cut

1;
