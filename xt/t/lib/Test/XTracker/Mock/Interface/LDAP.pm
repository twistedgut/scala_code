package Test::XTracker::Mock::Interface::LDAP;

use NAP::policy "tt", 'test';

use Test::MockObject;

use Net::LDAP::Entry;


sub setup_mock {
    my $self = shift;

    my $mock = Test::MockObject->new;
    $mock->fake_module(
        'Interface::LDAP',
        'connect'   => \&_connect,
        'get_user'  => \&_get_user,
        'dn_bind'   => \&_dn_bind,
        'search'    => \&_search,
    );

    return $mock;
}


sub _connect {
    return $_[0];
}

my $should_authenticate = 1;
sub _dn_bind {
    my $self = shift;

    return $should_authenticate;
}

my $user = 'it.god';
sub set_user {
    my $self     = shift;
    my $username = shift;

    $user = $username;
    return $user;
}

sub _get_user {
    my $self = shift;
    return $user;
}

my $dn = 'CN=IT God,OU=Users,OU=Whiteleys,DC=london,DC=net-a-porter,DC=com';
sub set_dn {
    my $self = shift;
    my $term = shift;

    $dn = $term;

    return;
}

sub get_dn {
    return $dn;
}


my %ldap_entry_attributes = (
    sAMAccountName  => [ 'it.god' ],
    mail            => 'example@net-a-porter.com',
    memberOf        => [
        'CN=dl_NAP_Brand_Westfield,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=gs_VMware_View_STD_Desktop,OU=sGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_Pre-order_Programme,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_Cando_Dev,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_Cando_All,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_Everyone@Westfield,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=Map_Home_Westfield,OU=sGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=xt_user,OU=sGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=xt_admin,OU=sGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=gs_Technical_Team,OU=sGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_IT_Project_Closeout,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_theOutnet_Technology_Team,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=us_xt_Administrator,OU=sGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_XT_Admin_Team,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_Backend_Team,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_IT_Developers_Team,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=dl_theOutnet_Non_Event_Stream,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=gs_Shared,OU=sGroups,DC=london,DC=net-a-porter,DC=com',
        'CN=gs_PRO_IT,OU=sGroups,DC=london,DC=net-a-porter,DC=com'
    ],
);

sub get_entry_attributes {
    return \%ldap_entry_attributes;
}

sub set_entry_attributes {
    my $self = shift;
    my $attributes = shift;

    %ldap_entry_attributes = (
        %ldap_entry_attributes,
        %{ $attributes },
    );

    return;
}

sub _search () {
    my $self = shift;

    my $entry = Net::LDAP::Entry->new;
    $entry->dn($self->get_dn);

    $entry->add ( %ldap_entry_attributes );

    return [ $entry ];
}

1;
