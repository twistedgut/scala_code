package XT::Net::Role::UserAgent;

use NAP::policy "tt", 'role';
use Module::Runtime 'require_module';
use LWP::UserAgent;
use IO::Socket::SSL;

use XTracker::Config::Local qw( config_var );

=head1 NAME

XT::Net::Role::UserAgent

=head1 DESCRIPTION

Role giving user agent capabilities

=head1 ATTRIBUTES

=head2 useragent

A user agent defaulting to LWP::UserAgent

=cut

has useragent => (
    is      => "ro",
    isa     => "LWP::UserAgent",
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $class = $self->useragent_class;
        require_module $class;
        $class->new(
            env_proxy => 1,
            timeout   => $self->timeout_sec,
            agent     => $self->version_string,
        );
    }
);

=head2 useragent_class

=cut

has useragent_class => (
    is      => "ro",
    lazy    => 1,
    default => 'LWP::UserAgent'
);

=head2 timeout_sec

=cut

has timeout_sec => (
    is      => "ro",
    lazy    => 1,
    default => sub { 20 },
);

=head1 METHODS

=head2 version_string

=cut

sub version_string {
    return "XTracker " . join(
        ", ",
        "Instance (" . config_var("XTracker", "instance") . ")",
        "Version (" . ($XTracker::Version::VERSION // 'Unknown') . ")",
        "IWS phase (" . (config_var('IWS', 'rollout_phase') // "Unknown") . ")",
    );
}

=head2 enable_ssl

Set SSL options on the user agent. This will enable HTTPS transport.

=cut

sub enable_ssl {
    my ($self, $args) = @_;

    $self->useragent->ssl_opts(
        SSL_verify_mode => SSL_VERIFY_PEER,
        verify_hostname => 0,
        SSL_version     => 'SSLv3',
    );

    if($args->{client_cert}){
        $self->useragent->ssl_opts(
            SSL_ca_file     => config_var("SSL", "ca_cert_file"),
            SSL_cert_file   => config_var("SSL", "client_cert_file"),
            SSL_key_file    => config_var("SSL", "private_key_file"),
        );
    }
}

=head2 is_ssl_enabled

=cut

sub is_ssl_enabled {
    my $self = shift;

    # Return true if useragent is SSL enabled
    return $self->useragent->ssl_opts > 1;
}
