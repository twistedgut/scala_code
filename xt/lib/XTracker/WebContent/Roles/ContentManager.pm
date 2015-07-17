package XTracker::WebContent::Roles::ContentManager;

use Moose::Role;

requires 'is_mychannel';
requires 'commit';
requires 'rollback';

=head1 NAME

XTracker::WebContent::Roles::ContentManager

=head1 DESCRIPTION

Role providing base interface for web update managers

=head1 ATTRIBUTES

=head2 schema

DBIC schema for XTracker

=cut

has schema =>  (
    is      => 'ro',
    isa     => 'Object',
);

=head2 channel_id

Channel id. Used to create lazily loaded attribute 'channel'.

=cut

has channel_id => (
    is      => 'rw',
    isa     => 'Int',
);

=head2 channel

Channel for this web update manager

=cut

has channel => (
    is      => 'ro',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        my $self = shift;

        return $self->schema->resultset('Public::Channel')->find($self->channel_id);
    },
);

=head1 METHODS

=head2 disconnect

No-op method to disconnect from storage engine

=cut

sub disconnect {}

=head1 SEE ALSO

L<XTracker::WebContent::StockManagment>

=head1 AUTHORS

Andrew Solomon <andrew.solomon@net-a-porter.com>,
Pete Smith <pete.smith@net-a-porter.com>,
Adam Taylor <adam.taylor@net-a-porter.com>,

=cut

1;
