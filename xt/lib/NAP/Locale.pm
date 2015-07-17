package NAP::Locale;

use NAP::policy "tt", qw( class );

use Data::Dump qw/pp/;

use POSIX;
use DateTime::Locale;
use XTracker::Config::Local qw( config_var );

=head1 NAME

NAP::Locale

=head1 DESCRIPTION

Class to localise data.

Provides methods to localise country names, currency names, dates,
numbers, prices and salutations for language translations.

Currently localises to Chinese, French and German languages without
any further locale specifics.

=head1 SYNOPSIS

    use NAP::Locale;

    my $loc = NAP::Locale( locale => 'zh_CN',
                           customer => $customer
                         );

    my $date = $loc->formatted_date( DateTime->now() );
    my $number = $loc->number(12345);
    my $currency = $loc->currency_name('GBP');
    my $price = $loc->price('£12,995.99');
    my $email_address = $loc->email_address('test@net-a-porter.com');

=head1 METHODS

=head2 new

Instantiate a new localisation object.

Requires locale, provided as a string, and a customer schema object.

=head2 locale

Get or set the locale to which the object localises.

A string containing a locale name (ie en_US or de_DE) or just the
language element of the locale name (ie de, fr, en or zh) may be provided
in which case the locale will be changed accordingly.

=head1 SEE ALSO

NAP::Locale::Role::Country
NAP::Locale::Role::CurrencyName
NAP::Locale::Role::Date
NAP::Locale::Role::EmailAddress
NAP::Locale::Role::Number
NAP::Locale::Role::Price
NAP::Locale::Role::Salutation
NAP::Locale::Role::EmailAddress

=cut

# old_locale needs to be the first accessor so we can be sure it it set
# correctly in order to be able to set back to it later.
has old_locale => (
    is          => 'ro',
    isa         => 'Str',
    init_arg    => undef,
    default     => sub {
        return config_var('Locale', 'default_locale') ?
            config_var('Locale', 'default_locale')
            : ( $ENV{LANG} ? $ENV{LANG} : 'C' );
        },
);

has customer => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Customer',
    required    => 1,
);

# Channel is not used yet as this is only going live for NAP
# When other brands go live for translations we will need this to
# be required
has channel => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Channel',
    lazy_build  => 1,
);

has locale => (
    is          => 'rw',
    isa         => 'Str', # Perhaps this should be MooseX::Types::Locale::Codes
    required    => 1,
    trigger     => \&_set_locale,
);

has localeconv => (
    is          => 'ro', # This accessor is set internally only
    isa         => 'HashRef',
    init_arg    => undef,
);

has language => (
    is          => 'ro',
    isa         => 'Str',
    writer      => '_set_language',
    init_arg    => undef,
);

has logger => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    lazy_build  => 1,
);

# this will use the Schema on the Customer
# record unless it is passed in on creation
has schema => (
    is          => 'ro',
    isa         => 'XTracker::Schema',
    lazy_build  => 1,
);

with 'NAP::Locale::Role::Number',
     'NAP::Locale::Role::Date',
     'NAP::Locale::Role::Salutation',
     'NAP::Locale::Role::Country',
     'NAP::Locale::Role::CurrencyName',
     'NAP::Locale::Role::EmailAddress',
     'NAP::Locale::Role::Product',
     'NAP::Locale::Role::Price';

# We use AUTOLOAD to ensure that calls to NAP::Locale never "fail" because
# an unknown method or accessor was called.
# In the event that a call to an unknown method or accessor is made AUTOLOAD
# will simply log the call and return the first param as is.
sub AUTOLOAD { ## no critic(ProhibitAutoloading,RequireArgUnpacking)
    my $self = shift;
    my $input = shift;
    return unless $input;

    my ($unknown_method) = our $AUTOLOAD =~ /::(\w+)$/;

    $self->logger->warn( "$unknown_method called but does not exist. Returning "
                         .pp(@_) );
    return $input;
}

# We use DESTROY to set localeconv back to what it was when we began
sub DEMOLISH {
    my $self = shift;
    my $global_destruction = shift;

    return if $global_destruction;

    eval {
        $self->locale($self->old_locale);
    };
    return;
}

sub BUILD {
    my $self = shift;

    $self->_set_locale();
}

sub _build_logger {
    my $self = shift;
    require XTracker::Logfile;
    return XTracker::Logfile::xt_logger( 'NAP_Locale' );
}

# _set_locale gets called as a trigger on the locale accessor. It needs
# to set the value of a number of accessors which are ro as well as to
# set its own accessor (without triggering it!) so we assign directly
# to the class hashref rather than the accessors.
#
# Yes this is awkward and not "the Moose way". There is however a good
# reason to do things this way.
sub _set_locale {
    my $self = shift;

    my %full_locale = (
        fr  => 'fr_FR',
        de  => 'de_DE',
        zh  => 'zh_CN',
        en  => 'en_US',
    );

    ( $self->{language} ) =  split( /_/, lc $self->locale );

    my $loc = POSIX::setlocale(LC_ALL, $self->locale);

    # If the requested language is not supported for the channel force the default
    unless ( $self->channel->supports_language( $self->language ) ) {
        $self->logger->warn( 'Language "'.$self->language.'" requested but not supported on this channel. Using system default instead.' );
        $self->_set_language( $self->schema->resultset('Public::Language')->get_default_language_preference->code );
    }

    if ( ! $loc ) {
        # If we don't get $loc from locale see if we can get it from
        # language
        my $locale = $full_locale{$self->language};

        # If we still don't have a locale set it to the default from the
        # config file if that exists or 'en_US' as a last resort
        if ( ! $locale ) {
            $locale = config_var('Locale', 'default_locale') ?
                config_var('Locale', 'default_locale') : 'en_US';
        }
        $self->{locale} = $locale;
        $loc = POSIX::setlocale(LC_ALL, $self->locale);
    }

    # We only need POSIX locale to be set for as long as it takes to do this
    $self->{localeconv} = POSIX::localeconv();

    # Set it back to the locale we were in when instantiated
    $loc = POSIX::setlocale(LC_ALL, $self->old_locale);
}

# We get the channel from the customer object. If Seaview changes the
# concept of the customer so that it is truly global (ie not channel
# specific) we'll need to do something else.
sub _build_channel {
    my $self    = shift;
    return $self->customer->channel;
}

# use the Customer record to get the Schema object
sub _build_schema {
    my $self    = shift;
    return $self->customer->result_source->schema;
}

no Moose;
