package Test::Role::Channel;

use NAP::policy "tt", qw( test role );


use XTracker::Database;

requires 'get_schema';

=head1 NAME

Test::Role::Channel - a Moose role to do channel-related stuff in
tests.

=head1 SYNOPSIS

    package Test::Foo;

    with 'Test::Role::Channel';

    my $nap = __PACKAGE__->channel_for_nap;
    my $out = __PACKAGE__->channel_for_out;
    my $mrp = __PACKAGE__->channel_for_mrp;

    my $channel = __PACKAGE__->channel->any_channel;

=cut

=head1 METHODS

=head2 channel_for_business( name => [nap|out|mrp] )

=head2 channel_for_business( id => $business_id )

Return a channel for the given name or id.

=cut

sub channel_for_business {
    my ( $self, %arg ) = @_;
    my $msg = "You need to pass a hash with a key of name or id";
    croak $msg unless ( keys %arg and keys %arg == 1 );

    my $params = defined $arg{name} ? { web_name => { ilike => "$arg{name}%" } }
               : defined $arg{id}   ? { business_id => $arg{id} }
               :                      croak $msg;

    return $self->_get_channels($params)->slice(0,0)->single;
}

=head2 channel_for_mrp

Returns the channel for Mr Porter on this DC.

=cut

sub channel_for_mrp { return $_[0]->channel_for_business(name=>'mrp'); }
sub mrp_channel { return shift->channel_for_mrp; }

=head2 channel_for_nap

Returns the channel for Net-A-Porter on this DC.

=cut

sub channel_for_nap { return $_[0]->channel_for_business(name=>'nap'); }
sub nap_channel { return shift->channel_for_nap; }

=head2 channel_for_out

Returns the channel for the Outnet on this DC.

=cut

sub channel_for_out { return $_[0]->channel_for_business(name=>'out'); }
sub out_channel { return shift->channel_for_out; }

=head2 channel_for_jc

Returns the channel for Jimmy Choo on this DC.

=cut

sub channel_for_jc { return $_[0]->channel_for_business(name=>'jc'); }
sub jc_channel { return shift->channel_for_jc; }

=head2 channel_for_any

Returns an unspecified channel on this DC.

Use this when you want to indicate that what you're testing isn't
channel specific, but you still need a channel.

=cut

sub channel_for_any { return $_[0]->channel_for_business(name=>'mrp'); }

=head2 any_channel

Returns a random non-fulfilment-only enabled channel.

=cut

sub any_channel {
    shift->_get_channels->fulfilment_only(0)->enabled->slice(0,0)->single;
}

sub _get_channels {
    my ( $self, $params ) = @_;
    return $self->get_schema->resultset('Public::Channel')->search($params);
}

=head2 fulfilment_only_channel

Returns a fulfilment only channel

=cut

sub fulfilment_only_channel {
    return shift->_get_channels->fulfilment_only(1)->enabled->slice(0,0)->single;
}

=head2 get_local_channel

  Test::XTracker::Data->get_local_channel($name)

Return back the DBIx row for a channel. If $name is provided it will try
to find it in the public.channel.web_name - its shorter ;)

=cut

sub get_local_channel{
    my($class,$name) = @_;
    my $schema = $class->get_schema;
    if (not defined $name) {
        $name = 'nap';
    }

    my $channel_rs = $schema->resultset('Public::Channel')->search({
        web_name => { ilike => "%${name}%" },
    });

    if ($channel_rs->count == 0) {
        diag "Cannot find a channel that matches '$name'";
        return;
    }

    if ($channel_rs->count > 1) {
        diag "Found more than one channel that matches '$name' - "
            ."be more specific";
        return;
    }

    return $channel_rs->first;
}

=head2 get_local_channel_or_nap

  Test::XTracker::Data->get_local_channel_or_nap($name)

Wraps get_local_channel and will give you nap channel if it can not find it


=cut

sub get_local_channel_or_nap {
    my($self,$name) = @_;

    # try find mr porter...
    my $channel = $self->get_local_channel($name);

    # ..otherwise cheat and use nap ;)
    if (not defined $channel) {
        $channel = $self->get_local_channel('nap');
        diag "  WARNING: using ". $channel->name ." cos could not find $name";
    }

    return $channel;
}

=head2 get_enabled_channels

Returns a resultset of currently enabled channels and tests that there is at
least one channel returned

=cut

sub get_enabled_channels {
    return shift->get_schema->resultset('Public::Channel')->enabled_channels;
}

=head2 get_enabled_channel_ids

Returns the ids of channels returned by L<get_enabled_channels>.

=cut

sub get_enabled_channel_ids {
    return $_[0]->get_enabled_channels->get_column('id')->all;
}

=head2 get_web_channels

Returns a resetulset of currently enabled channels that are also non-fulfilment only
and tests that there is at least one channel returned

=cut

sub get_web_channels {
    my($self) = @_;

    my $channel_rs = $self->get_enabled_channels->search({
        fulfilment_only => 0,
    });

    ok($channel_rs->count, 'we have more than 1 channel');
    return $channel_rs;
}

=head2 get_web_channel_ids

Returns the ids of channels returned by L<get_web_channels>.

=cut

sub get_web_channel_ids {
    return $_[0]->get_web_channels->get_column('id')->all;
}



1;
