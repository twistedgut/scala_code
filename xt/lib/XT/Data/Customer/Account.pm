package XT::Data::Customer::Account;

use NAP::policy "tt", 'class';
extends 'XT::Data';

with 'XT::Data::Role::StorageInteraction' =>
  { storage_class => 'XTracker::Schema::Result::Public::Customer',
    search_key => 'account_urn',
    search_field => 'urn',
  };

use Moose::Util::TypeConstraints;

use XT::Data::URI;
use XT::Data::Types qw/ DateStamp URN ResourceBool /;
use XT::Data::Trait::DBICLinked;
use XTracker::Logfile qw/ xt_logger /;

=head1 NAME

XT::Data::Customer::Account

=head1 DESCRIPTION

This class represents a customer account

=head1 TYPES

=cut

=head1 ATTRIBUTES

=head2 urn

=cut

has 'urn' => (
    is       => 'ro',
    isa      => 'XT::Data::Types::URN',
    required => 0,
    coerce   => 1,
);

=head2 customer_urn

=cut

has 'customer_urn' => (
    is       => 'rw',
    isa      => 'XT::Data::Types::URN',
    required => 0,
    coerce   => 1,
);

=head2 last_modified

=cut

has 'last_modified' => (
    is       => 'ro',
    isa      => 'XT::Data::Types::TimeStamp',
    required => 0,
    coerce   => 1,
);

=head2 email

=cut

has 'email' => (
    is          => 'rw',
    isa         => 'Str',
    traits      => [ qw/DBICLinked/ ],
    dbic_accessor => ['email'],
    required    => 0,
);

=head2 encrypted_password

=cut

has 'encrypted_password' => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 title

=cut

has 'title' => (
    is          => 'rw',
    isa         => 'Str',
    traits      => [ qw/DBICLinked/ ],
    dbic_accessor => ['title'],
    required    => 0,
);

=head2 first_name

=cut

has 'first_name' => (
    is          => 'rw',
    isa         => 'Str',
    traits      => [ qw/DBICLinked/ ],
    dbic_accessor => ['first_name'],
    required    => 0,
);

=head2 last_name

=cut

has 'last_name' => (
    is          => 'rw',
    isa         => 'Str',
    traits      => [ qw/DBICLinked/ ],
    dbic_accessor => ['last_name'],
    required    => 0,
);

=head2 addresses

=cut

has 'addresses' => (
    is          => 'rw',
    isa         => 'ArrayRef|Undef',
    required    => 0,
);

=head2 country_code

=cut

has 'country_code' => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 email_sub

=cut

has 'email_sub' => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 welcome_pack_sent

=cut

has 'welcome_pack_sent' => (
    is       => 'rw',
    isa      => 'XT::Data::Types::ResourceBool',
    required => 0,
    coerce   => 1,
);

=head2 porter_subscriber

=cut

has 'porter_subscriber' => (
    is       => 'rw',
    isa      => 'XT::Data::Types::ResourceBool',
    required => 0,
    coerce   => 1,
);

=head2 origin_id

=cut

has 'origin_id' => (
    is          => 'ro',
    isa         => 'Int',
    required    => 0,
);

=head2 origin_region

=cut

has 'origin_region' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 0,
);

=head2 origin_name

=cut

has 'origin_name' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 0,
);

=head2 date_of_birth

=cut

has 'date_of_birth' => (
    is       => 'ro',
    isa      => 'XT::Data::Types::DateStamp',
    required => 0,
    coerce   => 1,
);

=head2 category

=cut

has 'category' => (
    is       => 'rw',
    isa      => 'Str',
    traits => [ qw/DBICLinked/ ],
    dbic_accessor => [ 'category', 'category' ],
);

=head1 METHODS

=head2 as_dbi_like_hash

Returns a hash of the object data suitable for drop-in replacement of
DBI-based account data

=cut

sub as_dbi_like_hash {
    my $self = shift;
    my $account_data = {};

    # Stringify the date as required
    if(defined $self->date_of_birth){
        $self->date_of_birth->set_formatter(
            DateTime::Format::Strptime->new(pattern => '%F',
                                            time_zone => "UTC", ));
    }

    $account_data->{category}       = $self->category;
    $account_data->{urn}            = $self->urn;
    $account_data->{last_modified}  = $self->last_modified;
    $account_data->{title}          = $self->title;
    $account_data->{first_name}     = $self->first_name;
    $account_data->{last_name}      = $self->last_name;
    $account_data->{email}          = $self->email;
    $account_data->{date_of_birth}  = $self->date_of_birth;
    $account_data->{porter_subscriber} = $self->porter_subscriber;

    # Discover local database category_id
    if( exists $account_data->{category} ){
        my $local_category
          = $self->schema->resultset('Public::CustomerCategory')
                 ->search( { category => $self->{category} })
                 ->slice(0)->single;

        if( defined $local_category ){
            $account_data->{category_id} = $local_category->id;
        }
    }

    return $account_data;
}
