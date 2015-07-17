package XTracker::Config::Local;
use NAP::policy "tt", 'exporter';

=head1 NAME

XTracker::Config::Local

=cut

use Carp;

use Config::Any;
use Perl6::Export::Attrs;

use Data::Dumper;
use DateTime;
use DateTime::Format::Strptime;
use Catalyst::Utils;
use Data::Visitor::Callback;
use Path::Class;
use Sys::Hostname (); # don't export hostname() method
use Carp;

use vars qw/$CONFIG_FILE_PATH $APP_ROOT_DIR/;

# Preparation for DAVE
# This file should of course be transformed in a .in file
# rather than having this hardcoded path here.
# Let's go with the flow for now. PEC
if (defined $ENV{XTDC_CONFIG_FILE}) {
    # Prefer to load from env variable in case we're developing concurrently with
    # a RPM installation of XTDC
    $CONFIG_FILE_PATH ||= $ENV{XTDC_CONFIG_FILE};
}
elsif ( -e "/etc/xtdc/xtracker.conf" ) {
    $CONFIG_FILE_PATH = "/etc/xtdc/xtracker.conf";
}
else {
    die "\n\nYou appear to be missing the xtracker.conf file and its location.\n"
      . "In Live envs or envs provisioned by RPM's these configs should all live in /etc/xtdc...\n"
      . "Alternatively, if you're developing, you can export this ENV var XTDC_CONFIG_FILE with the location of xtracker.conf.\n"
      . "Please run perl Makefile.PL;make setup an use the instructions there to source your env file.\n\n";
}

=head1 METHODS

=cut

our %config;
sub load_config {

    my $hash = load_arbitrary_config($CONFIG_FILE_PATH);

    %config = %$hash;
    return %config;
}

sub load_arbitrary_config {
    my ($path) = @_;

    # read in the config file
    my $config = Config::Any->load_files( {
      use_ext => 1,
      files =>[ $path ],
    });

    if ($ENV{XT_CONFIG_DEBUG}) {
      warn "loaded config files from $path:\n";
      require Data::Dump;
      Data::Dump::pp(@$config);
    }

    my $hash = {};
    $hash = Catalyst::Utils::merge_hashes($hash, $_) foreach (map { values(%$_) } @$config);

    finalize_config($hash);

    return $hash;
}

# I've stolen these two from Catalyst::PLugin::ConfigLoader and adapted them to this XTDC paradigm.
# Hopefully Catalyst will arrive soon to XTDC and whoever reads this can have a laugh.
sub finalize_config {
    my $config = shift;
    my $v      = Data::Visitor::Callback->new(
        plain_value => sub {
            return unless defined $_;
            config_substitutions( $_ );
        }
    );
    $v->visit( $config );
}

sub config_substitutions {
    my $subs = {};

    $subs->{ env }    ||= sub { $ENV{$_[0]}||$_[1]; };
    $subs->{ ENV }    ||= sub { $ENV{$_[0]}||$_[1]; };
    $subs->{ literal } ||= sub { return $_[ 1 ]; };
    my $subsre = join( '|', keys %$subs );

    for ( @_ ) {
        s{__($subsre)(?:\((.+?)\))?__}{ $subs->{ $1 }->( $2 ? split( /,/, $2 ) : () ) }eg;
    }
}



load_config();

# If you really must hard-code something for some reason, put it in %defaults, and it will only be used if there is no config value
my %defaults = (
    Currency => {
        local_currency_code => 'GBP',
    },
);


sub app_root_dir() :Export() {

  unless ($APP_ROOT_DIR) {
    my $me = file(__FILE__);

    $APP_ROOT_DIR = $me->parent->parent->parent->parent->resolve->stringify . '/';
  }
  return $APP_ROOT_DIR;
}

=head2 config_var

=head3 Description

Returns the value of a named $variable from section $section of the
config file, or undef if the variable isn't in the config file.

=head3 Synopsis

$value = config_var($section, $variable);

=head3 Parameters

=over

=item C<$section>

=item C<$variable>

=back

=head3 Returns

Scalar or arrayref

=cut

sub config_var :Export(:DEFAULT) {
    my ( $section, $variable, @ancestry ) = @_;

    if ( exists $config{ $section } ) {
        if (ref $config{ $section } ne 'HASH') {
            confess("Not a HASH reference (section=$section,variable=$variable)");
        }
        elsif ( exists $config{ $section }{ $variable } ) {
            return $config{ $section }{ $variable };
        }
        elsif ( exists $config{$section}{INHERITFROM} ) {

            #Check that the current section isn't a 'superclass' of itself
            if ( grep( { $_ eq $section } @ancestry ) ) {

                # Circular inheritance detected! Avoid an infinite-loop condition
                carp "Configuration section [$section] inherits from itself!";
                return;
            }
            return config_var(
                $config{$section}{INHERITFROM},
                $variable,
                ( @ancestry, $section )
            );
        }
    }
    return _default_value( $section, $variable );
}

=head2 config_path($path) : $config_value

Return the $config_value corresponding to the $path
(e.g. "/Putaway/intransit_type"). Only two levels are supported
(Section and Variable name).

Note that the path starts with / .

=cut

sub config_path : Export() {
    my ($path) = @_;

    my ($section, $variable) = ( $path =~ m|^ / (\w+) / (\w+) |x );
    ( $section && $variable ) or confess("Invalid config path ($path)");

    return config_var($section, $variable);
}

=head2 condition_config_var($section, $variable) : $config_value

This allows a config value to depend on another config value, e.g. the
PRL Rollout Phase.

Return the current value depending on the "condition key" in the
config value at $section / $variable.

A "condition key" contains three things:

    a) A config_path, which is the condition.     e.g. /PRL/rollout_phase
    :  a colon separator                               :
    b) A value for when the condition is true.    e.g. Location
    |  a pipe alternator                               |
    c) A value for when the condition is false.   e.g. Container

Example: "/PRL/rollout_phase:Location|Container"

In this case: If the current "PRL rollout_phase" config value is true,
then the returned config value is "Location", otherwise it's
"Container".

=cut

sub condition_config_var : Export() {
    my ($section, $variable) = @_;
    my $config_key = config_var($section, $variable);

    my ($condition_config_path, $true_value, $false_value)
        = ( $config_key =~ m{^ (\S+?) : (.+?) \| (.+?) $}x );
    $condition_config_path
        or confess("The config_key ($config_key) doesn't look like a 'condition config key'");

    my $condition_config_value = config_path( $condition_config_path )
        // confess("Missing config_path($condition_config_path)\n");

    return $condition_config_value
        ? $true_value
        : $false_value;
}

=head2 maybe_condition_config_var($config_key) : $config_value

If $config_key looks like a "condition key" (see
C<condition_config_var>), return the current value depending on the
condition. If it looks like a normal key, just return the config value
as it's written in the config file.

=cut

sub maybe_condition_config_var : Export() {
    my ($section, $variable) = @_;
    return try {
        return condition_config_var($section, $variable);
    }
    catch {
        return config_var($section, $variable);
    };
}

sub get_section_keys :Export {
    my ($section) = @_;

    return if (not defined $config{$section});

    my @keys = keys %{$config{$section}};

    return \@keys;
}

sub _default_value {
    my ($section, $variable) = @_;

    #exists() is called twice to prevent auto-vivification of $defaults{section}
    if ( exists( $defaults{$section} ) and exists( $defaults{$section}{$variable} ) ) {
        return $defaults{$section}{$variable};
    }
    return;
}

sub config_section_slurp :Export(:DEFAULT) {
    my ($section,@ancestry)  = @_;
    # @ancestry contains a list of sections inherited from, to prevent
    # circular inheritance

    my $return_hash = {};

    if ( exists( $defaults{ $section } ) and not @ancestry ) {
    foreach my $k (keys %defaults) {
        $return_hash->{$k} = $defaults{$k};
    }
    }

    if (!config_section_exists($section)) {
    return $return_hash;
    }

    if ( exists( $config{$section}{INHERITFROM} ) ) {
        my $parent_hash = config_section_slurp(
            $config{$section}{INHERITFROM},
            ( @ancestry, $section )
        );
        foreach my $k (keys %$parent_hash) {
            $return_hash->{$k} = $parent_hash->{$k};
        }
    }

    foreach my $k (keys %{ $config{ $section } } ) {
        $return_hash->{$k} = $config{$section}{$k};
    }

    return $return_hash;
}

sub config_section_exists :Export(:DEFAULT) {
    my $section = shift;
    return $config{ $section };
}
sub config_section :Export {
    config_section_exists(@_);
}

sub get_config_sections :Export(:DEFAULT) {
    my ($regexp) = @_;
    my @sections = ();

    foreach my $section (keys(%config)) {
        if ($section =~ $regexp) {
            # If the regex has a subexpression, use that instead of the full
            # section
            push(@sections, ($1 ? $1 : $section));
        }
    }
    return @sections;
}

# Url
### Subroutine : hostname                       ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub hostname :Export() {
    return config_var('URL', 'url');
}

# there are a number of places where we hardcode 'fulcrum.net-a-porter.com' (e.g. DoUpload messages)
# this is annoying in DAVE and while the solution isn't perfect, i's a slight improvement on where we've been until now.
sub fulcrum_hostname :Export() {
    state $fulcrum_host;
    # if we have a value we've already worked it out once and don't need to again
    return $fulcrum_host
        if defined $fulcrum_host;

    # default to the name of the live server
    $fulcrum_host = 'fulcrum.net-a-porter.com';

    # if we look like a DAVE machine ...
    if (Sys::Hostname::hostname() =~ m{\A.+?(-.+?\.dave\.net-a-porter\.com)\z}) {
        $fulcrum_host = "fulcrum${1}";
    }

    return $fulcrum_host;
}

# Logging
### Subroutine : log_conf_dir                   ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub log_conf_dir :Export() {
    return config_var('Logging', 'log4perl');
}

# Email

=head2 returns_email

    $string = returns_email( $channel_config_section );
            or
    $string = returns_email( $channel_config_section, { schema => $schema, locale => 'fr_FR' } );
            or
    $string = returns_email( $channel_config_section, { schema => $schema, language => 'fr' } );

This will return the Returns email address found in the Config. If you pass a HASH Ref of
Arguments with a Schema and either a Locale or Language it will attempt to find the Localised
version of the Returns email address if it can't it will just return the one from the Config.

=cut

sub returns_email :Export() {
    return _email_address_helper( 'returns_email', @_ );
}

=head2 localreturns_email

    $string = localreturns_email( $channel_config_section );
            or
    $string = localreturns_email( $channel_config_section, { schema => $schema, locale => 'fr_FR' } );
            or
    $string = localreturns_email( $channel_config_section, { schema => $schema, language => 'fr' } );

This will return the Local Returns (Premier) email address found in the Config. If you pass a HASH Ref of
Arguments with a Schema and either a Locale or Language it will attempt to find the Localised version
of the Local Returns (Preimer) email address if it can't it will just return the one from the Config.

=cut

sub localreturns_email :Export() {
    return _email_address_helper( 'localreturns_email', @_ );
}

=head2 customercare_email

    $string = customercare_email( $channel_config_section );
            or
    $string = customercare_email( $channel_config_section, { schema => $schema, locale => 'fr_FR' } );
            or
    $string = customercare_email( $channel_config_section, { schema => $schema, language => 'fr' } );

This will return the Customer Care email address found in the Config. If you pass a HASH Ref of
Arguments with a Schema and either a Locale or Language it will attempt to find the Localised
version of the Customer Care email address if it can't it will just return the one from the Config.

=cut

sub customercare_email :Export() {
    return _email_address_helper( 'customercare_email', @_ );
}

### Subroutine : fulfilment_email               ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub fulfilment_email :Export() {
    my ($channel) = @_;
    my $config_section = 'Email_'.$channel;
    return config_var($config_section, 'fulfilment_email');
}

=head2 dispatch_email

    $string = dispatch_email( $channel_config_section );
            or
    $string = dispatch_email( $channel_config_section, { schema => $schema, locale => 'fr_FR' } );
            or
    $string = dispatch_email( $channel_config_section, { schema => $schema, language => 'fr' } );

This will return the Dispatch email address found in the Config. If you pass a HASH Ref of
Arguments with a Schema and either a Locale or Language it will attempt to find the Localised
version of the Dispatch email address if it can't it will just return the one from the Config.

=cut

sub dispatch_email :Export() {
    return _email_address_helper( 'dispatch_email', @_ );
}

### Subroutine : stockadmin_email               ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub stockadmin_email :Export() {
    my ($channel) = @_;
    my $config_section = 'Email_'.$channel;
    return config_var($config_section, 'stockadmin_email');
}

### Subroutine : samples_email                  ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub samples_email :Export() {
    my ($channel) = @_;
    my $config_section = 'Email_'.$channel;
    return config_var($config_section, 'samples_email');
}

=head2 shipping_email

    $string = shipping_email( $channel_config_section );
            or
    $string = shipping_email( $channel_config_section, { schema => $schema, locale => 'fr_FR' } );
            or
    $string = shipping_email( $channel_config_section, { schema => $schema, language => 'fr' } );

This will return the Shipping email address found in the Config. If you pass a HASH Ref of
Arguments with a Schema and either a Locale or Language it will attempt to find the Localised
version of the Shipping email address if it can't it will just return the one from the Config.

=cut

sub shipping_email :Export() {
    return _email_address_helper( 'shipping_email', @_ );
}

=head2 personalshopping_email

    $string = personalshopping_email( $channel_config_section );
            or
    $string = personalshopping_email( $channel_config_section, { schema => $schema, locale => 'fr_FR' } );
            or
    $string = personalshopping_email( $channel_config_section, { schema => $schema, language => 'fr' } );

This will return the Personal Shopping email address found in the Config. If you pass a HASH Ref of
Arguments with a Schema and either a Locale or Language it will attempt to find the Localised
version of the Personal Shopping email address if it can't it will just return the one from the Config.

=cut

sub personalshopping_email :Export() {
    return _email_address_helper( 'personalshopping_email', @_ );
}

=head2 fashionadvisor_email

    $string = fashionadvisor_email( $channel_config_section );
            or
    $string = fashionadvisor_email( $channel_config_section, { schema => $schema, locale => 'fr_FR' } );
            or
    $string = fashionadvisor_email( $channel_config_section, { schema => $schema, language => 'fr' } );

This will return the Fashion Advisor email address found in the Config. If you pass a HASH Ref of
Arguments with a Schema and either a Locale or Language it will attempt to find the Localised
version of the Fashion Advisor email address if it can't it will just return the one from the Config.

=cut

sub fashionadvisor_email :Export() {
    return _email_address_helper( 'fashionadvisor_email', @_ );
}

### Subroutine : ordertracker_email             ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub ordertracker_email :Export() {
    my ($channel) = @_;
    my $config_section = 'Email_'.$channel;
    return config_var($config_section, 'ordertracker_email');
}

### Subroutine : xtracker_email                 ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub xtracker_email :Export() {
    my ($channel) = @_;
    my $config_section = 'Email_'.$channel;
    return config_var($config_section, 'xtracker_email');
}

### Subroutine : xtadmin_email                  ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub xtadmin_email :Export() {
    my ($channel) = @_;
    my $config_section = 'Email_'.$channel;
    return config_var($config_section, 'xtadmin_email');
}

### Subroutine : premier_email                  ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub premier_email :Export() {
    my ($channel) = @_;
    my $config_section = 'Email_'.$channel;
    return config_var($config_section, 'premier_email');
}


### Subroutine : jq_failed_email                                   ###
# usage        : $array_ref = jq_failed_email();                     #
# description  : Returns a list of email addresses to send the       #
#                failed job notifications to. This will always       #
#                return an array even if there is only one address.  #
# parameters   : none                                                #
# returns      : An ARRAY REF pointing to a list of email addresses. #

sub jq_failed_email :Export() {

    my $email_addresses = config_var("job_queue","failed_job_email_to");
    my $email_list;

    if (ref($email_addresses) eq "ARRAY") {
        $email_list = $email_addresses;
    }
    else {
        $email_list = [ $email_addresses ];
    }

    return $email_list;
}

=head2 email_address_for_setting

    $string = email_address_for_setting( 'setting' );
                or
    $string = email_address_for_setting( 'setting', $channel_obj or $channel_config_section );

This will return an Email Address for the given setting, if either a Channel DBIC record or a
simple Channel Config Section (e.g. NAP) is supplied then it will search the email section in
the config for that channel first - '<Email_NAP>' - before then looking at the general email
section '<Email>'. If there is no channel information supplied then it will only search
through the '<Email>' section.

If no email address can be found then it will return an empty string.

=cut

sub email_address_for_setting :Export() {
    my ( $setting, $channel )   = @_;

    return ""       if ( !$setting );

    # by default search the un-channelised config section
    my @config_sections = ( 'Email' );

    my $config_section  = $channel;
    if ( ref( $channel ) ) {
        $config_section = $channel->business->config_section;
    }
    if ( $config_section ) {
        # make the channelised config section the first section searched
        unshift @config_sections, "Email_${config_section}";
    }

    my $email_address;

    SECTION:
    foreach my $section ( @config_sections ) {
        $email_address  = config_var( $section, $setting );
        last SECTION        if ( $email_address );
    }

    return $email_address || "";
}

=head2 all_channel_email_addresses

    $hash_ref   = all_channel_email_addresses( $channel_config_section )
            or
    $hash_ref   = all_channel_email_addresses( $channel_config_section, { schema => $schema, locale => 'fr_FR' } );
            or
    $hash_ref   = all_channel_email_addresses( $channel_config_section, { schema => $schema, language => 'fr' } );

This will return all Email Addresses that are in the 'Email' Config for the Sales Channel
Config Section provided. If you pass a HASH Ref of Arguments with a Schema and either a
Locale or Language it will attempt to find the Localised version of each of the email
addresses, if it can't it will just return the one from the Config.

=cut

sub all_channel_email_addresses :Export() {
    my ( $channel_config_section, $args )   = @_;

    return      if ( !$channel_config_section );

    my $try_localising  = 0;
    if ( $args ) {
        if ( my $error_msg = _email_address_helper_param_check( $args, 1 ) ) {
            croak $error_msg;
        }
        $try_localising = 1;
    }

    my $emails  = config_section_slurp( "Email_${channel_config_section}" );

    return $emails      if ( !$try_localising );

    # go through each email address and try and localise it
    foreach my $email_type ( keys %{ $emails } ) {
        $emails->{ $email_type }    = _get_localised_email_address(
            $args->{schema},
            $args->{locale} // $args->{language},
            $emails->{ $email_type },
        );
    }

    return $emails;
}

=head2 order_nr_regex

    $str = order_nr_regex();

Returns a string which can be used in a regex of the
combined values of the 'regex' setting in the Config
Group '<OrderNumber_RegEx>'. So that current valid
Order Numbers can be identified. See the function
'order_nr_regex_including_legacy' to include past
Order Number formats.

=cut

sub order_nr_regex :Export {
    my $regex = config_var( 'OrderNumber_RegEx', 'regex' );

    my $retval = $regex;

    if ( ref( $regex ) eq 'ARRAY' ) {
        # make up a Regex String 'ORing' all parts in the Config
        # use '(?: ... )' to make the brackets non-capturing
        $retval = '(?:' . join( '|', @{ $regex } ) . ')';
    }

    return $retval;
}

=head2 order_nr_regex_including_legacy

    $str = order_nr_regex_including_legacy();

Returns a string like the function 'order_nr_regex' does
but also includes the values in the config section
'<OrderNumber_RegEx>' for the 'legacy_regex' settings
so that older style Order Numbers can be checked for.

Use this for when searching for previous Orders but
don't use it to test for 'current' Order Numbers
which shouldn't match against the legacy RegExs use
the function 'order_nr_regex' instead.

=cut

sub order_nr_regex_including_legacy :Export() {
    my $current_regex = order_nr_regex() // '';

    my $legacy_regex = config_var( 'OrderNumber_RegEx', 'legacy_regex' );

    # if there aren't any Legacy RegExs then just return the current RegEx
    return $current_regex   if ( !defined $legacy_regex || $legacy_regex eq '' );

    my $retval = $legacy_regex;

    if ( ref( $legacy_regex ) eq 'ARRAY' ) {
        # make up the RegEx
        $retval = '(?:' . join( '|', @{ $legacy_regex } ) . ')';
    }

    # if there is a current RegEx then combine with the Legacy RegEx
    $retval = "(?:${current_regex}|${retval})"      if ( $current_regex ne '' );

    return $retval;
}


### Subroutine : contact_telephone             ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub contact_telephone :Export() {
    my ($channel) = @_;
    my $config_section = 'Company_'.$channel;
    return config_var($config_section, 'tel');
}

# Company
### Subroutine : comp_addr                      ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub comp_addr :Export() {
    my ($channel) = @_;
    my $config_section = 'Company_'.$channel;
    return config_var($config_section, 'addr');
}

### Subroutine : comp_tel                       ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub comp_tel :Export() {
    my ($channel) = @_;
    my $config_section = 'Company_'.$channel;
    return config_var($config_section, 'tel');
}

### Subroutine : comp_fax                       ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub comp_fax :Export() {
    my ($channel) = @_;
    my $config_section = 'Company_'.$channel;
    return config_var($config_section, 'fax') // '';
}

### Subroutine : comp_freephone                   ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub comp_freephone :Export() {
    my ($channel) = @_;
    my $config_section = 'Company_'.$channel;
    return config_var($config_section, 'freephone');
}

### Subroutine : comp_freephone                   ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub comp_contact_hours :Export() {
    my ($channel) = @_;
    my $config_section = 'Company_'.$channel;
    return config_var($config_section, 'contact_hours');
}


# Company
### Subroutine : return_addr                    ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub return_addr :Export() {
    my ($channel) = @_;
    my $config_section = 'Company_'.$channel;
    return config_var($config_section, 'return_addr');
}

# Company
### Subroutine : return_postcode                ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub return_postcode :Export() {
    my ($channel) = @_;
    my $config_section = 'Company_'.$channel;
    return config_var($config_section, 'return_postcode') // '';
}

=head2 dc_address

Given a channel, this will return the address of the DistributionCentre

param - $channel : The XTracker::Schema::Result::Public::Channel object for the channel required

return - $address_data : A hashref with the following keys:
    addr1       : First line of address
    addr2       : Second line of address
    addr3       : Third line of address
    postcode    : Postcode (if applicable)
    city        :
    country     : Country (name, not code)
    alpha-2     : ISO_3166-1_alpha-2 code for above country

=cut
sub dc_address :Export() {
    my ($channel) = @_;
    return {
        %{config_section_slurp('Company_' . $channel->business->config_section)->{DC_Address}},
        country     => config_var('DistributionCentre', 'country'),
        'alpha-2'   => config_var('DistributionCentre', 'alpha-2')
    };
}

### Subroutine : dc_fax                         ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub dc_fax :Export() {
   return config_var('DistributionCentre', 'fax');
}

=head2 return_export_reason_prefix

    $string = return_export_reason_prefix();

This returns the Reason For Export that appears on the Returns Proforma,
this will be different per DC hence it is in the config.

    Prefix Examples:
        DC1 - British
        DC3 - Hong Kong

=cut

sub return_export_reason_prefix :Export() {
    return config_var('DistributionCentre','return_export_reason_prefix') // '';
}

=head2 post_code_label

    $string = post_code_label();

Returns the Label to use for a Post Code for this DC for example:

    POST CODE
        or
    ZIP CODE

=cut

sub post_code_label :Export() {
    return config_var('DistributionCentre','post_code_label') // '';
}


# Sample Department
### Subroutine : samples_addr                   ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub samples_addr :Export(:Samples) {

    my $addr1   = config_var('Samples', 'addr1');
    my $addr2   = config_var('Samples', 'addr2');
    my $addr3   = config_var('Samples', 'addr3');
    my $country = config_var('Samples', 'country');

    return wantarray    ? ($addr1, $addr2, $addr3, $country)
                        : "$addr1, $addr2, $addr3, $country"
                        ;
}

### Subroutine : samples_tel                    ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub samples_tel :Export(:Samples) {
   return config_var('Samples', 'tel');
}

### Subroutine : samples_fax                    ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub samples_fax :Export(:Samples) {
   return config_var('Samples', 'fax');
}

### Subroutine : sample_upload_locations                                         ###
# usage        : $hash_ptr = sample_upload_locations( $channel_config );           #
# description  : This gets the details from the SampleUploadLocations section in   #
#                the config file for a particular channel. It returns the default  #
#                location along with an array of locations that a section can use. #
#                If there is only one location this is forced into an array.       #
# parameters   : A config section for a channel e.g. NAP or OUTNET.                #
# returns      : A pointer to a HASH.                                              #

sub sample_upload_locations :Export(:Samples) {
    my $channel     = shift;

    my %upload;

    my $default     = config_var("SampleUploadLocations_".$channel,"default");

    if ($default) {
        $upload{default}    = $default;

        my $location    = config_var("SampleUploadLocations_".$channel,"location");
        if (ref($location) eq "ARRAY") {
            $upload{location}   = $location;
        }
        else {
            $upload{location}   = [ $location ];
        }
    }

    return \%upload;
}

### Subroutine : stock_consistency_path                                  ###
# usage        : $scalar = stock_consistency_path()                        #
# description  : This returns the path for the Stock Consistency Reports.  #
# parameters   : None.                                                     #
# returns      : The Path with a '/' on the end.                           #

sub stock_consistency_path :Export() {
    my $path    = config_var("Statistics","stock_consistency_path");

    return  ( $path =~ m{/$} ? $path : $path . "/" );
}

### Subroutine : get_file_paths                                          ###
# usage        : $hash_ptr = get_file_paths($channel_config_section)       #
# description  : This returns a series of file paths used in copying       #
#                Slug images for a given Sales Channel.                    #
# parameters   : Channel Config Section.                                   #
# returns      : A pointer to a HASH containing the paths.                 #

sub get_file_paths :Export() {
    my $channel_config      = shift;

    my %paths;

    $paths{source_base}     = config_var("file_paths_".$channel_config,"source_base_path");
    $paths{destination_base}= config_var("file_paths_".$channel_config,"destination_base_path");
    $paths{slug_source}     = config_var("file_paths_".$channel_config,"slug_source");
    $paths{slug_destination}= config_var("file_paths_".$channel_config,"slug_destination");
    $paths{cms_source}      = config_var("file_paths_".$channel_config,"cms_source");
    $paths{feat_product_destination}    = config_var("file_paths_".$channel_config,"feat_product_destination");

    return \%paths;
}

### Subroutine : create_cms_page_channels                                ###
# usage        : $array_ptr = create_cms_page_channels()                   #
# description  : This returns an array of config sections for channels     #
#                that should create a cms page when a designer is created. #
# parameters   : None.                                                     #
# returns      : A pointer to an ARRAY containing the options.             #

sub create_cms_page_channels :Export() {

    my $retval;
    my $create_page;

    $create_page= config_var("Designer_CMS_Page","create_cms_page");
    $retval     = ( ref($create_page) eq "ARRAY" ? $create_page : [ $create_page ] );

    return $retval;
}

### Subroutine : get_pws_webservers                                      ###
# usage        : $array_ptr = get_pws_webservers()                         #
# description  : This returns an array of config sections for webservers.  #
# parameters   : None.                                                     #
# returns      : A pointer to an ARRAY containing the options.             #

sub get_pws_webservers :Export() {
    my $retval;
    my $webservers;

    $webservers = config_var('PWS', 'webserver');
    if ( defined $webservers ) {
        $retval     = ( ref($webservers) eq "ARRAY" ? $webservers : [ $webservers ] );
    }

    return $retval;
}

### Subroutine : get_cms_config                                          ###
# usage        : $hash_ptr = get_cms_config($channel_config_section)       #
# description  : This returns a series of CMS config options such as       #
#                common pages in a HASH. Any other relavant config options #
#                should be added to this function.                         #
# parameters   : Channel Config Section.                                   #
# returns      : A pointer to a HASH containing the options.               #

sub get_cms_config :Export() {
    my $channel_config      = shift;

    my %options;

    my $common_page = config_var("CMS_".$channel_config,"common_page");

    $options{common_page}   = ( ref($common_page) eq "ARRAY" ? $common_page : [ $common_page ] );

    return \%options;
}



# PEC TODO: please remove the following sub after all the wharehouses are using IWS.
# Also, have a look at ticket DCEA-1223 for more clues.

### Subroutine : get_picking_printer                                     ###
# usage        : $scalar = get_picking_printer(                            #
#                    $printer_type,                                        #
#                    $channel_config_section                               #
#                 );                                                       #
# description  : This returns a picking printer to use based on the type   #
#                passed in such as 'fast' or 'regular' and the sales       #
#                channel config section. Firstly it gets the default then  #
#                if there are any printers matching for the type and       #
#                channel returns those instead.                            #
# parameters   : A Printer Type - 'fast' or 'regular, Sales Channel        #
#                Config Section.                                           #
# returns      : The name of a printer.                                    #

sub get_picking_printer :Export() {

    my ( $prn_type, $config_section )   = @_;

    my $printer = "";


    $printer    = config_var("DefaultPickingPrinters",$prn_type."_".$config_section) || config_var("DefaultPickingPrinters",$prn_type);

    return $printer;
}


# XT Database
### Subroutine : xt_db_server                   ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub xt_db_server :Export() {
    return config_var('xtracker_Database', 'db_host');
}

### Subroutine : xt_db_server_dc1               ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub xt_db_server_dc1 :Export() {
    return config_var('dc1_Database', 'db_host');
}

#
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub xt_db_server_dc2 :Export() {
    return config_var('dc2_Database', 'db_host');
}

#
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub xt_db_server_dc3 :Export() {
    return config_var('dc3_Database', 'db_host');
}

### Subroutine : xt_db_name                     ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub xt_db_name :Export() {
    return config_var('xtracker_Database', 'db_name');
}

# CT Database
### Subroutine : ct_db_server                   ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub ct_db_server :Export() {
    return config_var('ct_read_Database', 'db_host');
}

### Subroutine : ct_db_name                     ###
# usage        :                                  #
# description  :                                  #
# parameters   :  none                            #
# returns      :                                  #

sub ct_db_name :Export() {
    return config_var('ct_read_Database', 'db_name');
}

# Web server
### Subroutine : www_root                       ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub www_root :Export() {
    return config_var('PWS', 'doc_root');
}

### Subroutine : server_admin                   ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub server_admin :Export() {
    return config_var('PWS', 'server_admin');
}

### Subroutine : pws_db_server                  ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub pws_db_server :Export() {
    return config_var('PWS', 'db_server');
}

### Subroutine : pws_db_name                    ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub pws_db_name :Export() {
    return config_var('PWS', 'db_name');
}

### Subroutine : instance                       ###
# usage        : my $i = instance();              #
# description  : returns this instance of XT      #
# parameters   : none                             #
# returns      : text :- 'UK', or 'US'            #

sub instance :Export() {
    return config_var('XTracker', 'instance');
}

### Subroutine :                                ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub ssh_known_hosts_file :Export() {
    return config_var('SSH', 'known_hosts_file');
}

### Subroutine :                                ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub staging_ssh_host :Export() {
    return config_var('Staging_SSH', 'host');
}

### Subroutine :                                ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub staging_ssh_user :Export() {
    return config_var('Staging_SSH', 'user');
}

### Subroutine :                                ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub staging_ssh_port :Export() {
    return config_var('Staging_SSH', 'port');
}

### Subroutine :                                ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub staging_ssh_identity_file :Export() {
    return config_var('Staging_SSH', 'identity_file');
}

### Subroutine :                                ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub staging_ssh_protocol :Export() {
    return config_var('Staging_SSH', 'protocol');
}

### Subroutine :                                ###
# usage        :                                  #
# description  :                                  #
# parameters   : none                             #
# returns      :                                  #

sub staging_ssh_cipher :Export() {
    return config_var('Staging_SSH', 'cipher');
}

### Subroutine : authentication_source                                    ###
# usage        : my $source = authentication_source();                      #
# description  : Where should XTracker authenticate against.                #
# parameters   : none                                                       #
# returns      : [ xtracker | msad ]                                        #

sub authentication_source :Export() {
    # FIXME: should check the values for these and tie them down to valid
    # FIXME: values at time of reading config to avoid runtime errors. Current
    # FIXME: values are 'xtracker' and 'ldap'
    return config_var('XTracker', 'authentication');
}

sub ldap_config :Export() {
    my $ldap_settings = {
            host    => config_var('LDAP', 'host'),
            domain  => config_var('LDAP', 'domain'),
    };

    return $ldap_settings;
}

### Subroutine : dhl_express_ftp                                                  ###
# usage        : my $dhl_ftp_hashref = dhl_express_ftp();                           #
# description  : obtains ftp address and login details for DHL Express ftp server   #
# parameters   : none                                                       #
# returns      : ftp address, username and password                         #

sub dhl_express_ftp :Export(:DEFAULT) {

    my $return_hash = {};

    $return_hash->{address} = config_var('DHL', 'express_ftp_address');
    $return_hash->{username} = config_var('DHL', 'express_ftp_username');
    $return_hash->{password} = config_var('DHL', 'express_ftp_password');

    return $return_hash;
}

### Subroutine : dhl_xmlpi                                                ###
# usage        : my $dhl_xmlpi_hahref = dhl_xmlpi();                        #
# description  : obtains address and login details for DHL XMLPI service    #
# parameters   : none                                                       #
# returns      : address, username, password, dhl_url, datatypes_url        #
#                dct_request_url, schema_url, dct_location_url              #

sub dhl_xmlpi :Export(:DEFAULT) {

    my $return_hash = {};

    $return_hash->{address} = config_var('DHL', 'xmlpi_address');
    $return_hash->{username} = config_var('DHL', 'xmlpi_username');
    $return_hash->{password} = config_var('DHL', 'xmlpi_password');

    $return_hash->{dhl_url} = config_var('DHL', 'xmlpi_dhl_url');
    $return_hash->{datatypes_url} = config_var('DHL', 'xmlpi_datatypes_url');
    $return_hash->{dct_request_url} = config_var('DHL', 'xmlpi_dct_request_url');
    $return_hash->{schema_url} = config_var('DHL', 'xmlpi_schema_url');
    $return_hash->{dct_location_url} = config_var('DHL', 'xmlpi_dct_location_url');
    $return_hash->{rou_location_url} = config_var('DHL', 'xmlpi_rou_location_url');
    $return_hash->{svl_location_url} = config_var('DHL', 'xmlpi_svl_location_url');
    $return_hash->{svl_header} = config_var('DHL', 'xmlpi_svl_header');
    $return_hash->{dct_header} = config_var('DHL', 'xmlpi_dct_header');
    $return_hash->{rou_header} = config_var('DHL', 'xmlpi_rou_header');

    $return_hash->{language_code} = config_var('DHL', 'xmlpi_language_code');
    $return_hash->{region_code} = config_var('DHL', 'xmlpi_region_code');
    $return_hash->{label_template} = config_var('DHL', 'xmlpi_label_template');
    $return_hash->{schema_version} = config_var('DHL', 'xmlpi_schema_version');
    $return_hash->{routing_version} = config_var('DHL', 'xmlpi_routing_version');
    $return_hash->{zpl2_page_demarcation} = config_var('DHL', 'xmlpi_zpl2_page_demarcation');
    $return_hash->{label_resolution} = config_var('DHL', 'xmlpi_label_resolution');
    $return_hash->{date_error_code} = config_var('DHL', 'xmlpi_date_error_code');
    $return_hash->{use_dhl_logo} = config_var('DHL', 'xmlpi_use_dhl_logo');

    return $return_hash;
}

### Subroutine : mainfest_level                       ###
# usage        :              #
# description  : obtains the level of manifesting     #
# parameters   :                              #
# returns      :   off/partial/full         #
sub manifest_level :Export() {
    return config_var('Manifest', 'level');
}

### Subroutine : manifest_countries                       ###
# usage        :              #
# description  : obtains a list of countries to be included in manifests - used in conjunction with a manifest level of 'partial'     #
# parameters   :                              #
# returns      :   array of country names         #

sub manifest_countries :Export() {

    my $country_list = config_var('Manifest', 'countries');

    my @countries = split /,/, $country_list;

    return \@countries;

}

=head2 is_staff_order_premier_channel

  usage        : $boolean   = is_staff_order_premier_channel(
                                        $sales_channel_config_section
                                    );

  description  : This will look in the 'StaffOrders' section in the conf file
                 and get all of the 'premier_channel_conf_section' settings
                 and see whether the conf section passed in is one of them,
                 if it is it will return true else false. This is currently
                 used by XT::OrderImporter to decide if an Outnet order
                 should be switched to premier shipment type.

  parameters   : Sales Channel Config Section.
  returns      : BOOLEAN 1 or 0.

=cut

sub is_staff_order_premier_channel :Export() {

    my $channel_conf_sect   = shift;

    die "No Sales Channel Conf Section Passed In"       if ( !defined $channel_conf_sect || $channel_conf_sect eq "" );

    my $retval  = 0;

    my $prem_sections   = config_var( 'StaffOrders', 'premier_channel_conf_section' );
    $prem_sections      = ( ref($prem_sections) eq 'ARRAY' ? $prem_sections : [ $prem_sections ] );

    if ( grep { $_ eq $channel_conf_sect } @{ $prem_sections } ) {
        $retval = 1;
    }

    return $retval;
}

=head2 arma_can_accept_exchange_charges

    $boolean    = arma_can_accecpt_exchange_charges();

This returns TRUE if the setting 'arma_accept_exchange_charges' in the 'xtracker_extras_XTDC?.conf' file in the 'DistributionCentre' section is set to 'yes'.

=cut

sub arma_can_accept_exchange_charges :Export() {

    my $retval  = 0;

    my $value   = config_var( 'DistributionCentre', 'arma_accept_exchange_charges' );
    if ( defined $value && $value eq "yes" ) {
        $retval = 1;
    }

    return $retval;
}

=head2 has_delivery_signature_optout

    $boolean    = has_delivery_signature_optout();

This returns TRUE if the setting 'has_delivery_signature_optout' in the 'xtracker_extras_XTDC?.conf' file in the 'DistributionCentre' section is set to 'yes'.

=cut

sub has_delivery_signature_optout :Export() {

    my $retval  = 0;

    my $value   = config_var( 'DistributionCentre', 'has_delivery_signature_optout' );
    if ( defined $value && $value eq "yes" ) {
        $retval = 1;
    }

    return $retval;
}

=head2 can_opt_out_of_requiring_a_delivery_signature

    $boolean = can_opt_out_of_requiring_a_delivery_signature();

Returns TRUE if setting 'can_opt_out_of_requiring_a_delivery_signature' in the 'xtracker_extras_XTDC?.conf' file in the 'DistributionCentre' section is set to 'yes'

=cut

sub can_opt_out_of_requiring_a_delivery_signature :Export() {
    my $retval  = 0;

    my $value   = config_var( 'DistributionCentre', 'can_opt_out_of_requiring_a_delivery_signature' );
    if ( defined $value && lc($value) eq "yes" ) {
        $retval = 1;
    }

    return $retval;
}

=head2 rma_cutoff_days_for_email_copy_only

    $days   = rma_cutoff_days_for_email_copy_only( $channel_config_section || $channel_record );

This returns the number of days Customer's have to request an RMA that is stated in their RMA Emails. It uses the
'Returns_[channel]' section and the setting 'email_copy_only_days_to_request_return_from_dispatch'.

It is NOT TO BE USED to calculate any return cutoff or expiry dates, for this please use the 'return_cutoff_days'
on the 'shipping_account' table which takes into consideration the amount of time we've estimated the delivery to take.

=cut

sub rma_cutoff_days_for_email_copy_only :Export() {
    my $channel     = shift;

    my $section     = 'Returns_';

    # get the config section suffic for the $section
    if ( ref( $channel ) =~ /Public::Channel/ ) {
        $section    .= $channel->business->config_section;
    }
    else {
        $section    .= $channel;
    }

    return config_var( $section, 'email_copy_only_days_to_request_return_from_dispatch' );
}

=head2 rma_expiry_days

    $days   = rma_expiry_days( $channel_config_section || $channel_record );

This returns the number of days a Customer has to Return an Item once they have requested an RMA. It uses
the 'Returns_[channel]' section and the setting 'email_copy_only_days_to_request_return_from_dispatch'.

=cut

sub rma_expiry_days :Export() {
    my $channel     = shift;

    my $section     = 'Returns_';

    # get the config section suffic for the $section
    if ( ref( $channel ) =~ /Public::Channel/ ) {
        $section    .= $channel->business->config_section;
    }
    else {
        $section    .= $channel;
    }

    return config_var( $section, 'expiry_days' );
}

=head2 auto_expire_rma_days

    $days   = auto_expire_rma_days( $channel_config_section || $channel_record, 'returns' || 'exchange' );

This returns the number of days after which a Return or Exchange would automatically expires. It uses
the 'Returns_[channel]' section and the setting 'auto_expire_return_days' or 'auto_expire_exchange_days'.


=cut

sub auto_expire_rma_days :Export() {
    my $channel = shift;
    my $type    = shift;

    my $section     = 'Returns_';
    my $setting     = 'auto_expire_'.$type.'_days';

    # get the config section suffic for the $section
    if ( ref( $channel ) =~ /Public::Channel/ ) {
        $section    .= $channel->business->config_section;
    }
    else {
        $section    .= $channel;
    }

    return config_var( $section, $setting );

}

=head2 order_importer_send_fail_email

    $should_i_send_error_email = order_importer_send_fail_email( $channel_config_section || $channel_record );

This returns 1 or 0 to indicate if Order Importer needs to send email on error by reading Config setting.
It uses the 'OrderImporter_[channel]' section and the setting 'send_error_email'.
Values for "send_error_email" can be yes/no.

If No Channel is passed then it will return 1, so that an email doesn still get sent to be on the safe side.

=cut

sub order_importer_send_fail_email: Export() {
    my $channel = shift;

    # if NO Channel then Return TRUE, to be cautious
    return 1        if ( !$channel );

    my $section = 'OrderImporter_';
    my $setting = 'send_error_email';

    # get the config section suffic for the $section
    if ( ref( $channel ) =~ /Public::Channel/ ) {
        $section    .= $channel->business->config_section;
    }
    else {
        $section    .= $channel;
    }

    my $result = config_var( $section, $setting );
    $result = $result ? uc($result) : '';

    if($result =~ 'YES') {
        return 1;
    } elsif ($result =~ 'NO'){
        return 0;
    } else {
        return $result;
    }

}

=head2 can_autofill_town_for_address_validation

    $boolean = can_autofill_town_for_address_validation( $address_validator, $country_code );

Pass an Address Validator and a 2 Character Country Code into this function and it will return
TRUE or FALSE depending on whether the Country has been configured to populate the Town
with the County if the Town is Empty.

    if ( can_autofill_town_for_address_validation( 'DHL', 'HK' ) ) {
        ...
    }

=cut

sub can_autofill_town_for_address_validation : Export {
    my ( $validator, $country_code )    = @_;

    if ( $validator && uc( $validator ) eq 'DHL' ) {
        my $autofill_town_section = config_var('DHL', 'autofill_town_if_blank' ) // {};
        return 1    if ( $autofill_town_section->{ $country_code } );
    }
    else {
        carp "Don't Know this Address Validator: '" . ( $validator // 'undef' ) . "'"
             . ", for '" . __PACKAGE__ . "::can_autofill_town_for_address_validation'";
    }

    return 0;
}

=head2 get_autofilled_town_for_address_validation

    $towncity = get_autofilled_town_for_address_validation( $address_validator, $country_code );

Pass an Address Validator and a 2 Character Country Code into this function and it will return
the default town/city value to be used for address validation. This arises because addresses for
the country do not have a town/city set, but require one for address validation.

=cut

sub get_autofilled_town_for_address_validation : Export {
    my ( $validator, $country_code )    = @_;

    if ( $validator && uc( $validator ) eq 'DHL' ) {
        my $autofill_town_section = config_var( 'DHL', 'autofill_address_validation_city' ) // {};
        return $autofill_town_section->{ $country_code } if $autofill_town_section->{ $country_code };
    }
    else {
        carp "Don't Know this Address Validator: '" . ( $validator // 'undef' ) . "'"
             . ", for '" . __PACKAGE__ . "::get_autofilled_town_for_address_validation'";
    }
    return undef;
}

=head2 use_alternate_country_code

    $new_country_code = use_alternate_country_code( $address_validator, $country_code );

Pass an Address Validator and a 2 Character Country Code into this function and it will return
the replacement country code which must be used for address validation. idation.

=cut

sub use_alternate_country_code : Export {
    my ( $validator, $country_code )    = @_;

    if ( $validator && uc( $validator ) eq 'DHL' ) {
        my $alternate_country_code = config_var( 'DHL', 'alternate_country_code_for_validation' ) // {};
        return $alternate_country_code->{ $country_code };
    }
    else {
        carp "Don't Know this Address Validator: '" . ( $validator // 'undef' ) . "'"
             . ", for '" . __PACKAGE__ . "::use_alternate_country_code'";
    }
    return undef;
}

=head2 can_truncate_addresses_for_premier_routing

    $boolean = can_truncate_addresses_for_premier_routing();

Returns TRUE or FALSE based on whether Address Lines should be
truncated if they exceed a maximum length when the Premier
Routing file is being generated. This could be different for
each DC.

=cut

sub can_truncate_addresses_for_premier_routing :Export {
    my $value = config_var( 'Carrier_Premier', 'truncate_address_lines_in_routing_file' ) // 'yes';

    return ( lc( $value ) eq 'yes' ? 1 : 0 );
}

=head2 can_listen_for_hotlist_update

    $boolean    = can_listen_for_hotlist_update();

Will return TRUE or FALSE depending on whether this DC should keep its 'hotlist_value' table
up to date with other DCs when a message appears on the 'online-fraud' topic.

=cut

sub can_listen_for_hotlist_update :Export {
    my $setting = lc( config_var('OnlineFraud','listen_for_hotlist_update') );

    return ( $setting eq 'yes' ? 1 : 0 );
}

=head2 should_authentication_respond_to_an_ajax_request

    $boolean = should_authentication_respond_to_an_ajax_request( $apache_obj );

Will return TRUE if the request was from AJAX and the URI is one that should
be handled differently when called using an AJAX request during Authentication.

=cut

sub should_authentication_respond_to_an_ajax_request :Export() {
    my $apache_obj  = shift;

    # if not called by an AJAX request then return FALSE
    return 0        unless ( XTracker::Utilities::was_sent_ajax_http_header( $apache_obj ) );

    # get a list of URLs that are valid
    my $ajax_uris   = config_var('AJAXAuthenticationCallerURL', 'url');
    $ajax_uris      = ( ref( $ajax_uris ) ? $ajax_uris : [ $ajax_uris ] );

    return ( scalar( grep { $_ eq $apache_obj->uri } @{ $ajax_uris } ) ? 1 : 0 );
}

=head2 should_login_respond_to_an_ajax_request

    $boolean = should_login_respond_to_an_ajax_request( $apache_obj );

Will return TRUE if the request was from AJAX and the Referer is one that should
be handled differently when called using an AJAX request during Login.

=cut

sub should_login_respond_to_an_ajax_request :Export() {
    my $apache_obj  = shift;

    # if not called by an AJAX request then return FALSE
    return 0        unless ( XTracker::Utilities::was_sent_ajax_http_header( $apache_obj ) );

    # get a list of URLs that are valid
    my $ajax_uris   = config_var('AJAXLoginRefererURL', 'url');
    $ajax_uris      = ( ref( $ajax_uris ) ? $ajax_uris : [ $ajax_uris ] );

    # get the Referer
    my $referer     = $apache_obj->headers_in->get('Referer') // '';

    return ( scalar( grep { $referer =~ m/\Q${_}\E/ } @{ $ajax_uris } ) ? 1 : 0 );
}

=head2 order_search_by_designer_result_file_path

    $string = order_search_by_designer_result_file_path();

Returns the path where Result files for the Order Search by Designer
functionality are created in.

=cut

sub order_search_by_designer_result_file_path : Export() {
    return config_var( 'SystemPaths', 'search_order_by_designer_results_dir' );
}


#########################
# UPS Carrier Automation
#########################

=head2 get_ups_qrt

  usage        : $scalar = get_ups_qrt( $channel_conf_section );

  description  : This returns the 'quality_rating_threshold' for the
                 UPS API Integration section for a Sales Channel.

  parameters   : A Sales Channel Configuration Section.
  returns      : A Scalar Containing the Value.

=cut

sub get_ups_qrt :Export(:carrier_automation) {

    my $channel_conf    = shift;

    die "No Sales Channel Config Section Passed"        if ( !$channel_conf );

    return config_var("UPS_API_Integration_".$channel_conf, 'quality_rating_threshold');
}


=head2 get_ups_api_credentials

  usage        : $hash_ref = get_ups_qrt( $channel_conf_section );

  description  : This returns the security credentials that are needed to connect
                 to the UPS API for a given Sales Channel. It returns a HASH Ref
                 containing the following details:
                  {
                    user_name => 'user_name',
                    password => 'password',
                    xml_access_key => 'xml_access_key'
                  }

  parameters   : A Sales Channel Configuration Section.
  returns      : A HASH Ref Containing the Credentials.

=cut

sub get_ups_api_credentials :Export(:carrier_automation) {

    my $channel_conf    = shift;

    die "No Sales Channel Config Section Passed"        if ( !$channel_conf );

    my $credentials = {};

    $credentials->{user_name}       = config_var("UPS_API_Integration_".$channel_conf, 'user_name');
    $credentials->{password}        = config_var("UPS_API_Integration_".$channel_conf, 'password');
    $credentials->{xml_access_key}  = config_var("UPS_API_Integration_".$channel_conf, 'xml_access_key');

    return $credentials;
}


=head2 get_ups_api_url

  usage        : $scalar = get_ups_api_url( $channel_conf_section );

  description  : This returns the Base URL to which all UPS API requests are made to.
                 You must pass in a Sales Channel Configuration Section to pick the
                 correct setting.

  parameters   : A Sales Channel Configuration Section.
  returns      : A Scalar Containing the Base URL

=cut

sub get_ups_api_url :Export(:carrier_automation) {

    my $channel_conf    = shift;

    die "No Sales Channel Config Section Passed"        if ( !$channel_conf );

    return config_var("UPS_API_Integration_".$channel_conf, 'base_url');
}


=head2 get_ups_api_service_suffix

  usage        : $scalar = get_ups_api_service_suffix(
                            $service,
                            $channel_conf_section
                    );

  description  : This returns the service suffix that should be appended to
                 the Base URL (see above) to make a call to the UPS API.
                 Need to pass in a Sales Channel Configuration Section along
                 with one of the following services:
                    av          - address validation
                    shipconfirm - initial call to book a shipment
                    shipaccept  - call to finalise the booking
                These services will have '_suffix' appended to them and then
                the value will be got from the conf file for the appropriate
                Sales Channel section.

  parameters   : A UPS API Service, A Sales Channel Configuration Section.
  returns      : A Scalar Containing the Service Suffix.

=cut

sub get_ups_api_service_suffix :Export(:carrier_automation) {

    my $service         = shift;
    my $channel_conf    = shift;

    die "No Service Passed"                             if ( !$service );
    die "No Sales Channel Config Section Passed"        if ( !$channel_conf );

    return config_var("UPS_API_Integration_".$channel_conf, $service."_service");
}


=head2 get_ups_max_wait_time

  usage        : $hash_ref = get_ups_max_wait_time( $channel_conf_section );

  description  : This returns the max time to wait in seconds before retrying
                 a UPS API Service call if it came back with a Transient error.
                 It also returns the maximum number of retries to attempt as well.
                 These settings are returned in an anonymous hash with the
                 following details:
                    {
                        max_wait => 'max_retry_wait_time',
                        max_retries => 'max_retries'
                    }
                 A Sales Channel Configuration Section should be passed in to get
                 the settings from the correct channel's config section.

  parameters   : A Sales Channel Configuration Section.
  returns      : A HASH Ref Containing the Retry Details.

=cut

sub get_ups_max_wait_time :Export(:carrier_automation) {

    my $channel_conf    = shift;

    die "No Sales Channel Config Section Passed"        if ( !$channel_conf );

    my $retry   = {};

    $retry->{max_wait}      = config_var("UPS_API_Integration_".$channel_conf, 'max_retry_wait_time');
    $retry->{max_retries}   = config_var("UPS_API_Integration_".$channel_conf, 'max_retries');

    return $retry;
}


=head2 get_ups_services

  usage        : $array_ref = get_ups_services(
                        $service_type,
                        $channel_conf_section
                    );

  description  : This returns all the different types of a given UPS Shipment Service that
                 is in the configuration file in an array. These types are to be tried
                 in the same order as returned in the array when trying to book a shipment
                 until one is accepted by UPS. This function will return an array ref of
                 hash refs containing each services code and description like the following:
                    [
                        {
                            code => '03',
                            description => 'UPS Ground'
                        }
                    ]
                 A Sales Channel Configuration Section should be passed in to get
                 the settings from the correct channel's config section.

  parameters   : A Service ('air' or 'ground'), A Sales Channel Configuration Section.
  returns      : An Array Ref of Hash Refs Containing the Details.

=cut

sub get_ups_services :Export(:carrier_automation) {

    my $service         = shift;
    my $channel_conf    = shift;

    die "No UPS Shipment Service Passed"                if ( !$service );
    die "No Sales Channel Config Section Passed"        if ( !$channel_conf );

    my $service_types    = [];

    my $code    = config_var("UPS_API_Integration_".$channel_conf, $service."_service_code");
    my $desc    = config_var("UPS_API_Integration_".$channel_conf, $service."_service_description");

    if ( $code ) {
        $code   = [ $code ]             if ( ref( $code ) ne "ARRAY" );
        $desc   = [ $desc ]             if ( ref( $desc ) ne "ARRAY" );

        foreach my $idx ( 0..$#{ $code } ) {
            push @{ $service_types }, {
                                        code        => $code->[$idx],
                                        description => $desc->[$idx]
                                    };
        }
    }

    return $service_types;
}


=head2 get_ups_api_warning_failures

  usage        : $array_ref = get_ups_api_warning_failures( $channel_conf_section );

  description  : This returns all of the warning codes that the UPS API might reply with
                 that we (NaP) should actually treat as failures and have our API
                 return with a FAIL. It will return a list or codes in an array ref.
                 A Sales Channel Configuration Section should be passed in to get
                 the settings from the correct channel's config section.

  parameters   : A Sales Channel Configuration Section.
  returns      : An Array Ref Containing the Codes.

=cut

sub get_ups_api_warning_failures :Export(:carrier_automation) {

    my $channel_conf    = shift;

    die "No Sales Channel Config Section Passed"        if ( !$channel_conf );

    my $codes   = config_var("UPS_API_Integration_".$channel_conf, "fail_warning_errcode");
    if ( $codes ) {
        $codes  = ( ref( $codes ) ne "ARRAY" ? [ $codes ] : $codes );
    }
    else {
        $codes  = [];
    }

    return $codes;
}

################################
# END OF UPS Carrier Automation
################################


sub config_file_path :Export() {
    return $CONFIG_FILE_PATH;
}

### Subroutine : xt_url_dc1                                              ###
# usage        :                                                            #
# description  :                                                            #
# parameters   :                                                            #
# returns      :                                                            #

sub xt_url_dc1 :Export() {
    return config_var( 'XT_URL_DC1', 'host' );
}

### Subroutine : xt_url_dc2                                              ###
# usage        :                                                            #
# description  :                                                            #
# parameters   :                                                            #
# returns      :                                                            #

sub xt_url_dc2 :Export() {
    return config_var( 'XT_URL_DC2', 'host' );
}

### Subroutine : xt_url_dc3                                              ###
# usage        :                                                            #
# description  :                                                            #
# parameters   :                                                            #
# returns      :                                                            #

sub xt_url_dc3 :Export() {
    return config_var( 'XT_URL_DC3', 'host' );
}

#############################################################
# Using: system_config, which is a Schema in the xTracker DB
#############################################################

=head2 sys_config_var

  usage        : $value = sys_config_var(
                        $schema,
                        $conf_group_name,
                        $conf_setting,
                        $channel_id (optional)
                    );

  description  : This returns the value for a setting in the system config tables
                 similar to how 'config_var' works for the regular conf settings.
                 It will return an Array ref if there is more than one value for a
                 setting.

  parameters   : A DBiC Schema Connection, The Name of the Conf Group, The Name of
                 the Conf Group Setting and A Sales Channel Id (optional).
  returns      : The value for setting could be Scalar or an Array Ref.

=cut

sub sys_config_var :Export(:DEFAULT) {

    my $schema          = shift;
    my $group_name      = shift;
    my $group_setting   = shift;
    my $channel_id      = shift;

    croak "No Schema Connection Passed"           if ( !$schema );
    croak "No Group Name Passed"                  if ( !$group_name );
    croak "No Group Setting Passed"               if ( !$group_setting );

    my $retval;

    $retval = $schema->resultset('SystemConfig::ConfigGroupSetting')
                        ->config_var( $group_name, $group_setting, $channel_id );

    return $retval;
}

sub sys_config_var_as_arrayref :Export(:DEFAULT) {

    my $config = sys_config_var( @_ ) // [];

    return ref( $config ) eq 'ARRAY'
        ? $config
        : [ $config ];

}

=head2 sys_config_groups

  usage        : $array_ref = sys_config_groups(
                        $schema,
                        $group_pattern
                    );

  description  : This returns a list of Config Groups that match the group pattern
                 passed in. It will return a list of the groups found in an array ref
                 with each element containing a hash ref which will have the following
                 details in it:
                        {
                            group_id    => 'group id',
                            name        => 'group name',
                            channel_id  => 'channel id',
                            channel_name=> 'name of sales channel',
                            channel_conf=> 'channel conf section'
                        }
                 If a group doesn't have any channel associated with it then the channel
                 information in the hash will be absent.

  parameters   : A DBiC Schema Connection, A RegExp Pattern to Search On.
  returns      : An Array Ref containing Hashes of the groups.

=cut

sub sys_config_groups :Export(:DEFAULT) {

    my $schema              = shift;
    my $group_pattern       = shift;

    die "No Schema Connection Passed"           if ( !$schema );
    die "No Group Pattern Passed"               if ( !$group_pattern );
    die "Group Pattern Not a RegExp"            if ( ref( $group_pattern ) ne "Regexp" );

    my $retval;

    $retval = $schema->resultset('SystemConfig::ConfigGroup')
                        ->get_groups( $group_pattern );

    return $retval;
}


=head2 get_packing_stations

  usage        : $array_ref = get_packing_stations(
                        $schema,
                        $channel_id
                    );

  description  : This returns a list of available packing stations for
                 a given Sales Channel Id. It uses the settings in the
                 table of the 'system_config' schema to produce the list.
                 An array ref is provided listing the names of the packing
                 stations.

  parameters   : A DBiC Schema Connection, A Sales Channel Id.
  returns      : An Array Ref of the Packing Stations.

=cut

sub get_packing_stations :Export(:carrier_automation) {

    my $schema          = shift;
    my $channel_id      = shift;

    die "No Schema Connection Passed"           if ( !$schema );
    die "No Sales Channel Id Passed"            if ( !$channel_id );

    my $retval;

    $retval = $schema->resultset('SystemConfig::ConfigGroupSetting')
                        ->config_var( "PackingStationList", "packing_station", $channel_id );

    if ( $retval ) {
        $retval = ( ref($retval) eq "ARRAY" ? $retval : [ $retval ] );
    }

    return $retval;
}

=head2 get_packing_station_printers

  usage        : $hash_ref = get_packing_station_printers(
                        $schema,
                        $packing_station
                    );

  description  : This returns the printers assigned to a packing station.
                 It will return the document and label printers in a hash
                 with the following details:
                    {
                        document => 'doc_printer',
                        label => 'lab_printer',
                        card => 'card_printer'  # if it exists

                    }

  parameters   : A DBiC Schema Connection, A Packing Station.
  returns      : A HASH Ref Containing the Document & Label Printers.

=cut

sub get_packing_station_printers :Export(:carrier_automation) {

    my $schema          = shift;
    my $packing_station = shift;
    my $premier_station = shift;
    $premier_station //= 0;

    die "No Schema Connection Passed"           if ( !$schema );
    die "No Packing Station Passed"             if ( !$packing_station );

    my $printers;

    my $doc_printer;
    my $lab_printer;

    $doc_printer        = sys_config_var( $schema, $packing_station, 'doc_printer' );
    $lab_printer        = sys_config_var( $schema, $packing_station, 'lab_printer' );

    if ( $doc_printer && $lab_printer ) {
        $printers->{document}   = $doc_printer;
        $printers->{label}      = $lab_printer;
    } elsif($premier_station && $doc_printer) {
        # Premier stations only require a document printer, not a label
        $printers->{document}   = $doc_printer;
    }

    my $card_printer        = sys_config_var( $schema, $packing_station, 'card_printer' );

    if ( $card_printer ) {
        $printers->{card}   = $card_printer;
    }

    return $printers;
}

=head2 get_shipping_printers

  usage        : $hash_ref = get_shipping_printers(
                        $schema
                    );

  description  : This returns all the shipping printers known,
                 as a pair of arrays, under the keys I<document>
                 and I<label>, of C<name> => C<lp_name> hashes.

  parameters   : A DBiC Schema
  returns      : A hash ref containing two refs to arrays
                 of Document & Label Printer names.

=cut

sub get_shipping_printers :Export() {
    my $schema = shift;

    my $printers;

    my $rs = $schema->resultset('SystemConfig::ConfigGroupSetting');

    my $docs = $rs->config_vars_by_group( 'ShippingDocumentPrinters' );

    foreach my $doc (@$docs) {
        my $name = (keys %$doc)[0];

        push @{$printers->{document}},{ name    => $name,
                                        lp_name => $doc->{$name}
                                      };
    }

    my $labs = $rs->config_vars_by_group( 'ShippingLabelPrinters' );

    foreach my $lab (@$labs) {
        my $name = (keys %$lab)[0];

        push @{$printers->{label}},{ name    => $name,
                                     lp_name => $lab->{$name}
                                   };
    }

    return $printers;
}

=head2 get_fraud_check_rating_adjustment

  usage        : $hash_ref = get_fraud_check_rating_adjustment(
                        $schema,
                        $channel_id,
                    );

  description  : This returns rating adjustment for given channel
                 from the system_config.config_group_setting table.

  parameters   : A DBiC Schema, channel id
  returns      : A hash ref containing  key as "setting name" and value as rating adjustment(integer)

=cut

sub get_fraud_check_rating_adjustment :Export() {
    my $schema          = shift;
    my $channel_id      = shift;

    die "No Schema Connection Passed"           if ( !$schema );
    die "No Sales Channel Id Passed"            if ( !$channel_id );

    my $fraud_check_values;

    my $rs       = $schema->resultset('SystemConfig::ConfigGroupSetting');
    my $values   = $rs->config_vars_by_group( 'FraudCheckRatingAdjustment',$channel_id );


    foreach my $value (@$values) {
        my $name = (keys %$value)[0];
        $fraud_check_values->{$name} = $value->{$name};
    }


    return $fraud_check_values;
}


=head2 get_premier_printers

  usage        : $hash_ref = get_premier_printers(
                        $schema
                    );

  description  : This returns all the premier printers known,
                 as a pair of arrays, under the keys I<document>
                 and I<address_card>, of C<name> => C<lp_name> hashes.

  parameters   : A DBiC Schema
  returns      : A hash ref containing two refs to arrays
                 of Document & Address Card names.

=cut

sub get_premier_printers :Export() {
    my $schema = shift;

    my $printers;

    my $rs = $schema->resultset('SystemConfig::ConfigGroupSetting');

    my $docs = $rs->config_vars_by_group( 'PremierShippingPrinters' );

    foreach my $doc (@$docs) {
        my $name = (keys %$doc)[0];

        push @{$printers->{document}},{ name    => $name,
                                        lp_name => $doc->{$name}
                                      };
    }

    my $cards = $rs->config_vars_by_group( 'PremierAddressCardPrinters' );

    foreach my $card (@$cards) {
        my $name = (keys %$card)[0];

        push @{$printers->{address_card}},{ name    => $name,
                                            lp_name => $card->{$name}
                                        };
    }

    return $printers;
}

=head2 get_shipping_restriction_actions_by_type

    $hash_ref   = get_shipping_restriction_actions_by_type( $schema );

Will return the Actions that need to be taken when a Shipping Restriction Type (such as CITES or Fish & Wildlife) are found.
These settings are in the System Config tables under the group name 'ShippingRestrictionActions'.

These actions are either 'Restriction' meaning a Product can NOT be shipped to a destination or a 'Notification' meaning that
an internal notification should be sent advising people that an Order contains a restricted product for a destination.

Results will be returned in a hash ref:

    {
        'CITES'             => 'restrict',
        'Fish & Wildlife'   => 'notify',
        ...
    }

=cut

sub get_shipping_restriction_actions_by_type :Export() {
    my $schema  = shift;

    # $settings will contain an array of hash refs
    my $settings    = $schema->resultset('SystemConfig::ConfigGroupSetting')
                                ->config_vars_by_group('ShippingRestrictionActions');

    my %hash;
    foreach my $setting ( @{ $settings } ) {
        my ( $type, $action )   = each %{ $setting };
        $hash{ uc( $type ) }    = lc( $action );
    }

    return \%hash;
}

=head2 isa_finance_manager_user

  usage        : $boolean   = isa_finance_manager_user(
                        $schema,
                        $user_name
                    );

  description  : This looks through the system_config.config_group_setting
                 table to see if the user name supplied is one of the ones
                 in the config group 'Finance_Manager_Users'.

  parameters   : A DBiC Schema Connection, A User Name.
  returns      : A Boolean result either TRUE (1) or FALSE (0).

=cut

sub isa_finance_manager_user :Export() {

    my $schema      = shift;
    my $user_name   = shift;

    die "No Schema Connection Passed"           if ( !$schema );
    die "No User Name Passed"                   if ( !$user_name );

    my $result  = 0;

    my $list    = sys_config_var( $schema, 'Finance_Manager_Users', 'user' );

    # force it to be an Array Ref
    $list   = ( ref($list) eq "ARRAY" ? $list : [ $list ] );

    # check to see if the user id passed is in the above list
    if ( grep { lc($_) eq lc($user_name) } @{ $list } ) {
        $result = 1;
    }

    return $result;
}


=head2 scalar internal_staff_shipping_sku ( schema, channel_id )

Returns the shipping_sku to be used for internal staff orders for a given
channel_id

=cut

sub internal_staff_shipping_sku :Export() {
    my $schema      = shift;
    my $channel_id   = shift;

    die "No Schema Connection Passed" if ( !$schema );
    die "No channel_id" if ( !$channel_id );

    my $shipping_sku = sys_config_var(
        $schema,'Internal Staff Order','shipping_sku',$channel_id);

    # sys_config_var returns scalar or array ref - only expect one
    if (ref($shipping_sku) eq 'ARRAY') {
        return $shipping_sku->[0];
    }
    return $shipping_sku;
}

=head2 use_acl_to_build_main_nav

    $boolean = use_acl_to_build_main_nav( $schema );

Returns TRUE or FALSE based on the 'build_main_nav' setting in the System Config
for the 'ACL' group.

=cut

sub use_acl_to_build_main_nav :Export() {
    my $schema  = shift;

    die "No Schema Connection Passed"           if ( !$schema );

    my $value   = sys_config_var( $schema, 'ACL', 'build_main_nav' ) // 'off';

    return ( lc( $value ) eq 'on' ? 1 : 0 );
}

=head2 acl_insecure_paths

    $array_ref = acl_insecure_paths();

Returns the paths in the 'insecure_paths' part of the 'ACL' Config section.

=cut

sub acl_insecure_paths : Export() {
    my $config = config_var( 'ACL', 'insecure_paths' ) // {};
    my $paths  = $config->{path} // [];

    # for some reason need to clone the Array Ref returned
    # when this is called in Plack::Middleware otherwise
    # contents of the config can be changed by the caller
    # TODO: find out why!
    return [ ( ref( $paths ) ? @{ $paths } : $paths ) ];
}

sub my_own_url :Export() {
    return config_var('XT_URL_'.(config_var('DistributionCentre','name')),'host');
}

=head2 iws_location_name

Returns a string with the name of iws_location_name

=cut

sub iws_location_name :Export() {
    return config_var('IWS', 'location_name');
}

=head2 to_putaway_cancelled_location_name : $location_name

Returns a string with the name of the Location used to transfer
Cancelled items to Putaway (or Putaway Prep) from e.g. Packing
Exception.

=cut

sub to_putaway_cancelled_location_name :Export() {
    return config_var('Putaway', 'Locations')->{Cancelled};
}

=head2 local_timezone

 my $timezone = local_timezone

Returns a L<DateTime::TimeZone> object set for what should be the user's local
time. Currently the implementation of this just always returns the local
timezone of the server, but if we move over to doing this correctly now, less
future pain.

=cut

# From the DateTime docs:
#
# Determining the local time zone for a system can be slow. If $ENV{TZ}  is not
# set, it may involve reading a number of files in /etc or elsewhere. If you
# know that the local time zone won't change while your code is running, and you
# need to make many objects for the local time zone, it is strongly recommended
# that you retrieve the local time zone once and cache it

our $LOCAL_TIMEZONE = DateTime::TimeZone->new( name => 'local' );
sub local_timezone :Export() { return $LOCAL_TIMEZONE; }

=head2 local_date_format / local_datetime_format

 my $format = local_date_format;

Returns a L<DateTime::Format::Strptime> object setup to correctly show the
date or datetime. At the moment, these will always return formatters of the
style:

 30-12-2010 10:35

or

 30-12-2012

Respectively. In the future, this may return an application-specific localized
version.

=cut

our $LOCAL_DATETIME_FORMAT = DateTime::Format::Strptime->new(
    pattern => '%d-%m-%Y %H:%M',
);
sub local_datetime_format :Export() { return $LOCAL_DATETIME_FORMAT; }

our $LOCAL_DATE_FORMAT = DateTime::Format::Strptime->new(
    pattern => '%d-%m-%Y',
);
sub local_date_format :Export() { return $LOCAL_DATE_FORMAT; }


=head2 local_datetime_now

Returns a L<DateTime> object created to now(), with the formatter and time_zone
set to C<local_timezone> and C<local_datetime_format> respectively.

=cut

sub local_datetime_now :Export() {
    return DateTime->now(
        time_zone => local_timezone(), formatter => local_datetime_format() );
}



sub default_carrier :Export() {
    my ($is_ground) = @_;

    my @keys = ("default_carrier", "default_ground_carrier");
    @keys = reverse @keys if($is_ground);

    for my $config_key (@keys) {
        if(my $carrier = config_var("DistributionCentre", $config_key)) {
            return $carrier;
        }
    }

    die(
        "No default_carrier found, check the config files for DistributionCentre/ "
            . join(" | ", @keys),
    );
}

=head2 enable_edit_purchase_order

Used to enable or disable edit purchase order features in XT.

Will be disabled when fully supported in Fulcrum.

Returns true if edit purchase order features is disabled on the config file (hence enabled on fulcrum)

Currently defaults to enabled.

=cut

sub enable_edit_purchase_order :Export() {
    # If the edit_purchase_order_rollout_phase is set at 0,
    # it means that the legacy principle that every PO should be editable in XT prevails.
    # If no such flag is set on the config variables, then the legacy behaviour stil persists
    my $EditPO_rollout_phase = config_var('Features', 'edit_purchase_order_rollout_phase') // 0;
    if ($EditPO_rollout_phase == 0){
        return 1;
    }else{
        return;
    }
}


=head2 has_cmsservice

    $boolean    = has_cmsservice(channel);

This returns TRUE if the setting 'use_service' in the 'xtracker_extras_XTDC?.conf' file in the 'CMSService_<channel_name>' section is set to 'yes'.

=cut

sub has_cmsservice :Export() {
    my ($channel) = @_;

    my $retval  = 0;

    my $config_section = 'CMSService_'.$channel;
    my $value = config_var($config_section, 'use_service');

    if ( defined $value && $value eq "yes" ) {
        $retval = 1;
    }

    return $retval;
}



=head2 upload_optimisation_settings

    $hashref = upload_optimisation_settings();

This returns a hashref containing a key value pair with the enable optimization upload flag per business

=cut

sub upload_optimisation_settings :Export() {
    return config_section_slurp('OptimizedUploadForBusiness');
}

=head2 use_optimised_upload

    $boolean = use_optimised_upload(business)

This returns TRUE if the confuguration specifies that optimized
upload is enabled for the business passed as parameter

=cut

sub use_optimised_upload :Export() {
    my $business_shortname = shift;
    return config_section_slurp('OptimizedUploadForBusiness')->{$business_shortname};
}

# common function for getting Emails Addresses from the Config
# and then also getting a Localised version, if one is available
sub _email_address_helper {
    my ( $email_address, $channel, $args )  = @_;

    my $try_localising  = 0;
    if ( $args ) {
        if ( my $error_msg = _email_address_helper_param_check( $args ) ) {
            croak $error_msg;
        }
        $try_localising = 1;
    }

    my $config_section = 'Email_' . $channel;
    my $email   = config_var( $config_section, $email_address );

    return $email       if ( !$try_localising );
    return _get_localised_email_address( $args->{schema}, $args->{locale} // $args->{language}, $email );
}

# common parameter checking for email address helper functions
sub _email_address_helper_param_check {
    my ( $args, $caller_level ) = @_;

    # get infomation about what called this function
    my @caller          = caller( $caller_level || 2 );
    my $function_name   = $caller[3];

    my $common_msg  = "for '${function_name}'";
    return "Second Parameter should be a HASH Ref ${common_msg}"         if ( ref( $args ) ne 'HASH' );
    return "No Schema passed in Arguments ${common_msg}"
                                        if ( !$args->{schema} || ref( $args->{schema} ) !~ m/Schema/ );
    return "No Locale or Language passed in Arguments ${common_msg}"
                                        if ( !exists( $args->{locale} ) && !exists( $args->{language} ) );

    return;
}

# common function used to get a localised version of an email address
sub _get_localised_email_address {
    # using explicit way of calling because of circular
    # references in using 'XTracker::EmailFunctions' normally
    ## no critic(ProhibitAmpersandSigils)
    return &XTracker::EmailFunctions::localised_email_address( @_ );
}

=head2 get_postcode_required_countries_for_preorder

    $arrayref = get_postcode_required_countries_for_preorder();

This returns list of countries for which postcode is a required field by reading config setting for "PreOrderPostcodeRequired"
for currenct DC

=cut


sub get_postcode_required_countries_for_preorder :Export() {

    my $countries = config_var('PreOrderAddress', 'postcode_required_for_country');

    if ( $countries && ref($countries) ne 'ARRAY' ) {
        $countries = [$countries];
    }
    return $countries // [];

}

=head2 get_required_address_fields_for_preorder

=cut

sub get_required_address_fields_for_preorder :Export {

    my $fields = config_var( 'PreOrderAddress', 'field_required' );

    return defined $fields
        ? ref( $fields ) eq 'ARRAY'
            ? $fields
            : [ $fields ]
        : [];

}

=head2 putaway_intransit_type() : "Container" | "Location"

Return the config /Putaway/intransit_type ("Container" | "Location").

This determines which kind of temporary way we store the items on
their way (intransit) to Putaway. Either they're kept in the
Container, or they're stored in the Cancelled-to-Putaway Location.

=cut

sub putaway_intransit_type : Export() {
    my $intransit_type = maybe_condition_config_var("Putaway", "intransit_type");

    my $valid_types = {
        Container => 1,
        Location  => 1,
    };
    $valid_types->{ $intransit_type }
        or confess("Invalid /Putaway/intransit_type ($intransit_type)");

    return $intransit_type;
}

=head2 send_multi_tender_notice_for_country

    send_notice() if send_multi_tender_notice_for_country($schema, $country);

Returns true if the country given is listed in the Multi_Tender_Shipping_Notice
system config setting.

=cut

sub send_multi_tender_notice_for_country :Export() {
    my ( $schema, $country ) = @_;

    die "No Schema Connection Passed" unless $schema;
    die "No country passed" unless $country;

    return sys_config_var( $schema, 'Multi_Tender_Shipping_Notice', $country ) // 0;
}

=head2 get_names_for_orderimporter_preparser

    hash_ref   = get_names_for_preparser( $schema );

Will return the values we can use while pre-processing order importer xml.
These settings are in the System Config table under the group name 'OrderImporterPreParser'.

Setting are of format:   settingname-name = value
we split by 'Hyphens' and create a hash ref of name and values for the settingname.


Results will be returned in a hash ref.

if config data is
    tender_type-klarna = card
    tender_type-somename = somevalue
    something-name = value

it returns
    {
        tender_type => {
            klarna => card,
            someone =>somevalue
        },
        something => {
            name => value
        }
    }

=cut

sub get_names_for_orderimporter_preparser :Export() {
    my $schema  = shift;

    # $settings will contain an array of hash refs
    my $settings    = $schema->resultset('SystemConfig::ConfigGroupSetting')
                                ->config_vars_by_group('OrderImporterPreParser');

    my %hash;
    foreach my $setting ( @{ $settings } ) {
        my ( $name, $value )    = each %{ $setting };
        my ( $type, $setting )  = split( /-/, $name, 2 );

        $hash{$type}{$setting}  =   $value;
    }

    return \%hash;
}

=head2 get_namespace_names_for_psp

    hash_ref   = get_namespace_names_for_psp( $schema );

Will return the values we can use for PSP calls.
These settings are in the System Config table under the group name 'PSPNamespace'.

Results will be returned in a hash ref:

    {
        'giftvoucher_sku'    => 'gift_voucher',
        'giftvoucher_name'   => 'Gift Voucher',
        ...
    }

=cut

sub get_namespace_names_for_psp :Export() {
    my $schema  = shift;

    # $settings will contain an array of hash refs
    my $settings    = $schema->resultset('SystemConfig::ConfigGroupSetting')
                                ->config_vars_by_group('PSPNamespace');

    my %hash;
    foreach my $setting ( @{ $settings } ) {
        my ( $name, $value )   = each %{ $setting };
        $hash{ $name }    =  $value;
    }

    return \%hash;
}

=head2 address_formatting_messages_for_country( $schema, $country_code )

Returns a HashRef of messages for each C<Order::Address> field, for the given
<$country_code>.

    my $messages = address_formatting_messages_for_country( $schema, 'DE' );

The result ($messages in the example above) will contain something like the
following:

    {
        address_line_1  => 'Some message for Address Line 1',
        postcode        => 'Some message for the Postcode',
    }

=cut

sub address_formatting_messages_for_country :Export() {
    my ( $schema, $country_code ) = @_;

    # These messages are only used for information, so we can just silently
    # return an empty HashRef for missing parameters.
    return {} unless defined $schema;
    return {} unless length( $country_code );

    my $message_list = sys_config_var_as_arrayref(
        $schema, 'AddressFormatingMessagesByCountry', $country_code );

    # Translate the list of configuration settings into a HashRef.
    return {
        map { split /:/ }
        @$message_list
    };

}

=head2 get_tender_type_from_config

   my $return_value =  get_tender_type_from_config( $schema, 'klarna');

Returns tender_type to be used from config var group 'OrderImporterPreParser'.
If config is not present returns what was passed in.

=cut

sub get_tender_type_from_config :Export() {
    my $schema = shift;
    my $tender_type = shift;

    #Get Order Importer Namespace Names for tender_type
    my $config_names = get_names_for_orderimporter_preparser($schema);
    my $tender_config_names = $config_names->{'tender_type'};

     #CANDO-8584
    if ( exists $tender_config_names->{ lc ( $tender_type ) } )  {
        return $tender_config_names->{ lc ( $tender_type) };
    } else {
        return $tender_type;
    }
}

=head2 can_deny_store_credit_for_channel

If Store Credit refund is a valid option for the channel.

=cut

sub can_deny_store_credit_for_channel :Export() {
    my ($schema, $channel_id) = @_;

    return sys_config_var(
        $schema,
        'Refund',
        'deny_store_credit',
        $channel_id
    );

}

=head2 get_reservation_commission_cut_off_date

Returns cut_off date with timestamp to be used for calculating 'Reservation Commission'

my $date  = $self->get_reservation_commission_cut_off_date ( $schema, $channel_id);

=cut

sub get_reservation_commission_cut_off_date :Export() {
    my $schema      = shift;
    my $channel_id  = shift;

    die "No Schema Connection Passed" unless $schema;
    die "No Sales Channel Id Passed" unless $channel_id ;

    # Get commission interval from config
    my $commission_unit  = sys_config_var( $schema, 'Reservation', 'sale_commission_unit', $channel_id );
    my $commission_value = sys_config_var( $schema, 'Reservation', 'sale_commission_value', $channel_id );
    my $commission_use_end_of_day = sys_config_var( $schema, 'Reservation','commission_use_end_of_day', $channel_id );

    if( $commission_unit && $commission_value ) {
        my $cut_off = $schema->db_now()->add( lc( $commission_unit ) => $commission_value );
        if( $commission_use_end_of_day )  {
              $cut_off->set(
                hour => 23,
                minute => 59,
                second => 59
              );
        }
        return $cut_off;
    }

    return ;
}

1;
