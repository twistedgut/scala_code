package XTracker::Schema::ResultSet::Public::Language;

use strict;
use warnings;

use Carp;

use base 'DBIx::Class::ResultSet';

use XTracker::Config::Local qw( config_var );
use XTracker::Logfile       qw( xt_logger );
use Try::Tiny;

=head2 search_by_code

    my $lang_obj = $schema->resultset('Public::Language')->search_by_code('en');

Return the DBIx object for the language code

=cut

my $logger = xt_logger(__PACKAGE__);

sub get_all_language_codes {
    my $self = shift;

    return $self->get_column('code')->all;
}

sub get_language_from_code {
    my ($self, $code) = @_;

    carp "No Language Code Passed" unless $code;

    return try {
        return $self->search({code => lc($code)})->first
    }
    catch {
        $logger->warn($_);
        return;
    };
}

sub get_default_language_preference {
    my ($self) = @_;

    return try {
        return $self->search({code => lc(config_var('Customer', 'default_language_preference'))})->first
    }
    catch {
        $logger->warn($_);
        return;
    };
}

=head2 get_all_languages_and_default

    $hash_ref = $self->get_all_languages_and_default;

Will return a HashRef of Language Ids and their Language Records and also a
key called 'default' which holds the Default Language for the DC.

=cut

sub get_all_languages_and_default {
    my $self    = shift;

    my %languages       = map { $_->id => $_ } $self->all;
    $languages{default} = $self->get_default_language_preference;

    return \%languages;
}

1;
