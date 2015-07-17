package XTracker::Interface::LDAP;

use NAP::policy "tt", 'class';
extends 'Interface::LDAP';

use XTracker::Logfile       qw( xt_logger );
use XTracker::Config::Local qw( config_var ldap_config );
use XTracker::Utilities::ACL    qw( filter_acl_roles_and_get_role_names );

has ldap_config => (
    is          => 'ro',
    isa         => 'HashRef',
    lazy_build  => 1
);

has '+host'     => (
    is          => 'rw',
    isa         => 'Str|ArrayRef',
    lazy_build  => 1,
);

has '+domain'   => (
    is          => 'rw',
    isa         => 'Str|ArrayRef',
    lazy_build  => 1,
);

has '+user'     => (
    is      => 'rw',
    isa     => 'Str',
    default => sub {
        return config_var('LDAP','default_ldap_login') // '';
    },
);

has '+pass'     => (
    is      => 'rw',
    isa     => 'Str',
    default => sub {
        return config_var('LDAP','default_ldap_password') // '';
    },
);

has '+timeout'  => (
    is      => 'rw',
    isa     => 'Int',
    default => sub {
        return config_var('LDAP','default_ldap_timeout') // 10;
    },
);

has '+port'     => (
    is      => 'rw',
    isa     => 'Int',
    default => => sub { return config_var('LDAP','default_ldap_port') // 389; },
);

has 'logger_output' => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    lazy_build  => 1,
);

sub _build_ldap_config {
    return ldap_config();
}

sub _build_host {
    return $_[0]->ldap_config->{host};
}

sub _build_domain {
    return $_[0]->ldap_config->{domain};
}

sub _build_logger_output {
    require XTracker::Logfile;
    return XTracker::Logfile::xt_logger();
}

# We need to be able to fall back through a list of domains to bind
# with so we wrap "around" dn_bind and iterate through the list of
# domains until we are able to bind with one of them.
around 'dn_bind' => sub {
    my $method = shift;
    my $self = shift;
    my @original_params = @_;

    # If $self->domain is not an array ref no need to fall back
    return $self->$method(@original_params) unless ref $self->domain eq 'ARRAY';

    my $retval;

    foreach my $domain ( @{ $self->domain } ) {
        $self->domain($domain);

        last if $retval = $self->$method(@original_params);
    }

    return $retval;
};

sub authenticate {
    my($self,$user,$pass) = @_;

    die "You must pass the username" unless $user;
    die "You must pass the password" unless $pass;

    if (not  $self->dn_bind($user,$pass)) {
        $self->logger( "Failed bind as $user" );
        return 0;
    }

    $self->logger( "Bound fine as $user" );
    return 1;
}

sub get_user_attributes {
    my ( $self, $user ) = @_;

    die "You must supply a username" unless $user;

    my $attributes = {};

    $self->connect;
    if ( ! $self->dn_bind( $self->user, $self->pass ) ) {
        $self->logger( "Failed bind as $user" );
        return $attributes;
    }

    # We need to force the search to be against the global catalogue
    # which means the domain must be set to only net-a-porter.com
    $self->domain('net-a-porter.com');

    my $results = $self->search('sAMAccountName='. $user);
    my $result_count = $#{$results} + 1;

    if ( $result_count < 1 ) {
        $self->logger_output->warn( "Cannot find LDAP account '$user'" );
        return $attributes;
    }
    $attributes->{email} = $results->[0]->get_value('mail');

    my $dn = $results->[0]->get_value('distinguishedName');
    $attributes->{groups} = $self->get_ldap_groups_by_dn( $dn );

    return $attributes;
}

sub _get_cn_list_from_search_result {
    my ( $self, $result ) = @_;

    my $list = [];
    foreach my $entry ( @{$result} ) {
        push @$list, $entry->get_value('cn');
    }
    return $list;
}

sub get_ldap_groups_by_dn {
    my ( $self, $dn ) = @_;

    die "You must pass in the distinguishedName" unless $dn;

    # The member specification below is what makes this return nested groups
    my $search_filter = '(&(objectclass=group)(member:1.2.840.113556.1.4.1941:='.$dn.'))';

    my $result = $self->search($search_filter);
    return $self->_get_cn_list_from_search_result($result);
}

sub get_ldap_roles {
    my $self = shift;

    my $prefix = $self->get_ldap_role_prefix();

    my $bind = $self->dn_bind( $self->user, $self->pass );
    if ( blessed($bind) && $bind->is_error ) {
        die "Cannot bind ".$bind->error;
    }

    # The groupType below tells AD to return security groups
    my $search_filter = '(&(objectclass=group)(name='.$prefix.'*)(groupType:1.2.840.113556.1.4.803:=2147483648))';
    my $results = $self->search($search_filter);
    return filter_acl_roles_and_get_role_names( $self->_get_cn_list_from_search_result($results) );
}

sub get_ldap_role_prefix {
    my $self = shift;

    my $prefix = config_var('ACL', 'role_parsing')->{role_prefix};
    die "LDAP role_prefix local config missing" unless $prefix;

    return $prefix;
}

sub logger {
    my ( $self, $message ) = @_;

    $self->logger_output->info( $message ) if $self->debug;
}

1;
__END__

=head1 NAME

XTracker::Interface::LDAP - Wrapper for Interface::LDAP for XTracker specifics

=head1 VERSION


=head1 SYNOPSIS

use XTracker::Interface::LDAP;

my $ldap = XTracker::Interface::LDAP->new( {
    host    => ,
    base    => ,
});

$ldap->debug(1);

$ldap->connect();

$ldap->bind();

$ldap->search('(cn=Foo Bar)');

$ldap->authenticate($user,$pass);

$ldap->get_member_of('(sAMAccountName=j.tang)');

$ldap->get_departments('(sAMAccountName=j.tang)');

$ldap->get_groups_from_entries( $arrayref_of_ldap_entry_objects );

$ldap->get_ldap_roles();

=head1 DESCRIPTION

A module with XTracker specific LDAP system functionality

=cut
