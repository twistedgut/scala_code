package NAP::Locale::Role;
use NAP::policy "tt", 'role';

requires 'locale';
requires 'localeconv';
requires 'logger';

use XTracker::Utilities     qw( :string );

=head1 NAME

NAP::Locale::Role

=head1 DESCRIPTION

Base class for all Locale Roles

=head1 SYNOPSIS

    package NAP::Locale::Role::MyRole
    use NAP::policy "tt", 'role';

    with 'NAP::Locale::Role';

=cut


=head2 trim_str

    $string = $locale_obj->trim_str( $string );

Remove leading and trailing whitespace.

=cut

sub trim_str {
    my ( $self, $string )   = @_;
    return trim( $string );
}
