package Interface::LDAP;
use NAP::policy "tt", 'class';
use version; our $VERSION = qv('1.0.0');
use Net::LDAP;

has host        => ( is => 'rw', isa => 'Str|ArrayRef', required => 1 );
has domain      => ( is => 'rw', isa => 'Str' );
has port        => ( is => 'rw', isa => 'Int' );
has user        => ( is => 'rw', isa => 'Str' );
has pass        => ( is => 'rw', isa => 'Str' );
has timeout     => ( is => 'rw', isa => 'Int' );

has debug       => ( is => 'rw' );
has error       => ( is => 'rw' );
has ldap        => ( is => 'rw' );

sub connect {
    my($self) = @_;
    my $host = $self->host;
    my %options = ( version => 3 );

    foreach my $option ( qw( port timeout debug ) ) {
        $options{$option} = $self->$option if defined $self->$option;
    }

    my $ldap = Net::LDAP->new(
        $host, %options
    ) or die "Cannot connect to server: ". ref $host ? (join(':', @{$host}) ) : $host;

    $self->logger("Connected to ".$ldap->host);

    $ldap->start_tls( verify => 'none' );
    $self->logger("Started TLS to secure connection");
    $self->ldap($ldap);

    return;
}

sub get_dn {
    my($self) = @_;

    return $self->user .'@'. $self->domain;
}

sub bind {
    my($self,$user,$pass) = @_;
    my $ldap = $self->ldap;

    die "username not defined" if (not defined $user);
    die "password not defined" if (not defined $pass);

    die "Not connected to ldap server" if (not defined $ldap);

    my $status = $ldap->bind( $user, password => $pass );

    $self->logger( "Connected as $user" ) ;

    if ($status->code) {
        $self->error( $status->error );
        return 0;
    }

    return 1;
}

sub dn_bind {
    my($self,$user,$pass) = @_;
    my $ldap = $self->ldap;
    $self->user( $user ) if $user;
    $self->pass( $pass ) if $pass;

    die "username not defined" if (not defined $self->user);
    die "password not defined" if (not defined $self->pass);

    die "Not connected to ldap server" if (not defined $ldap);

    $self->logger( "Attempt bind with ". $self->get_dn .":".
        $self->pass ) ;

    my $status = $ldap->bind(
        dn => $self->get_dn,
        password => $self->pass
    );

    if ($status->code) {
        $self->error( $status->error );
        return 0;
    }

    $self->logger( "Connected as $self->user" ) ;

    return 1;
}

sub unbind {
    my($self) = @_;
    return $self->ldap->unbind;
}

sub base {
    my($self) = @_;
    my $base = '';

    # Only works by hostname, NOT IP
    my @nodes = split  /\./, $self->domain;

    foreach my $node ( @nodes ) {
        # "DC=london,DC=net-a-porter,DC=com"
        chomp $node;
        $base .= "DC=$node,";
    }

    chop $base;

    return $base;
}

sub search {
    my($self,$filter) = @_;
    my $ldap = $self->ldap;
    my $results = undef;

    die "Not connected to ldap server" if (not defined $ldap);
    $filter = '' if (not defined $filter);

    my $base = $self->base;
    $self->logger( "Searching for '$filter':". $base ) ;

    my $set = $ldap->search(
        base    => $base,
        filter  => $filter,
    );

    $self->logger( "I am still here after search" ) ;

    # check on the success of the search
    $set->code and die $set->error;

    foreach my $entry ( $set->all_entries ) {
        push @{$results}, $entry;
        #return $entry;
    }

    $self->logger( "Found ". ($#{$results}+1) ) ;

    return $results;
}

sub get_user {
    my $self = shift;

    return $self->user // '';
}

sub logger {
    my ( $self, $message ) = @_;

    warn $message if ( $message && $self->debug );
}

1;
__END__

=head1 NAME

Interface::LDAP - Wrapper to provide simplified access to Net::LDAP

=head1 VERSION


=head1 SYNOPSIS

use Interface::LDAP;

my $ldap = Interface::LDAP->new( {
    host    => ,
    port    => ,
    user    => ,
    pass    => ,
    base    => ,
});

$ldap->debug(1);

$ldap->connect();

$ldap->bind($user,$pass);

$ldap->dn_bind($user,$pass);

$ldap->search('(cn=Foo Bar)');

=head1 DESCRIPTION

A package to pull out none-NAP specific code applying NET::LDAP

=head1 AUTHOR

Jason Tang

=cut
