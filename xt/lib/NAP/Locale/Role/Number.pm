package NAP::Locale::Role::Number;
use NAP::policy "tt", 'role';

with 'NAP::Locale::Role';

use Number::Format;

=head1 NAME

NAP::Locale::Role::Number

=head1 DESCRIPTION

Locale implementation for numbers, at present there's only one
method to format a number.

=head1 SYNOPSIS

    package NAP::Locale
    use NAP::policy "tt", 'class';

    with 'NAP::Locale::Role::SomeOtherRole';
    ...
    with 'NAP::Locale::Role::Number';

=head1 METHODS

=head2 number( $number[, $precision] )

Formats the given C<$number> (using C<$precision> if provided,
otherwise defaulting to whatever the locale requires) correctly
for the current locale. If C<$number> is a string already containing
formatting, it'll be coerced into a number first.

Returns either the formatted C<$number>, $C<$number> if anything
went wrong, or empty string if nothing was passed in.

    $formatted_number = $locale->number( 12345.67 );

=cut

sub number {
    my ( $self, $number, $precision ) = @_;

    unless ( defined $number ) {

        $self->logger->warn( __PACKAGE__ . '::number - requires a number' );

        # We return an emtpy string, as we don't want to insert anything unexpected
        # into any output.
        return '';

    }

    # Default the result to whatever was passed in.
    my $result = $number;

    # Remove everything other than numbers, minus sign and decimal points.
    $number =~ s/[^0-9.-]//g;

    if ( $number ) {
        # If we have something left to work with.

        # NAP::policy should escalate warnings, but it doesn't seem to!
        local $SIG{__WARN__} = sub { die @_ };

        try {

            my $nf = Number::Format->new(
                %{ $self->localeconv }
            );

            $result = $nf->format_number( $number, $precision );

        }

        catch {

            # If anything went wrong, add a warning to the log.
            $self->logger->warn( __PACKAGE__ . "::number - format_number failed: $_" );

        };

    } else {

        $self->logger->warn( __PACKAGE__ . '::number - number does not contain anything numeric' );

    }

    return $result;

}

