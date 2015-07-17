package XTracker::Schema::ResultSet::SystemConfig::ConfigGroup;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Carp;

=head2 get_groups

  usage        : $array_ref = $schema->resultset('SystemConfig::ConfigGroup')
                            ->get_groups(
                                    $group_pattern,
                        );

  description  : This searches for groups in the 'config_group' table based on
                 the search pattern passed in. It will return an array ref of
                 the results with each element containing a hash containing the
                 following details:
                        {
                            group_id    => 'group id',
                            name        => 'group name',
                            channel_id  => 'channel id',
                            channel_name=> 'name of sales channel',
                            channel_conf=> 'channel conf section'
                        }
                 If a group does not have any channel associated with it then the channel
                 information in the hash will be absent.

  parameters   : A RegExp to Search for Groups On.
  returns      : An Array Ref containing a Hash of the Groups.

=cut

sub get_groups {
    my $rs              = shift;
    my $group_pattern   = shift;

    my $retval;

    my $results = $rs->search(
                                {
                                    active  => 1,
                                },
                                {
                                    '+select'   => [ qw( channel.name business.config_section ) ],
                                    '+as'       => [ qw( channel_name config_section ) ],
                                    join    => { channel => 'business' },
                                    order_by=> 'me.id'
                                }
                            );

    while ( my $rec = $results->next ) {
        if ( $rec->name =~ $group_pattern ) {
            my $row     = {
                    group_id=> $rec->id,
                    name    => $rec->name
                };
            if ( $rec->channel_id ) {
                $row->{channel_id}  = $rec->channel_id;
                $row->{channel_name}= $rec->get_column('channel_name');
                $row->{channel_conf}= $rec->get_column('config_section');
            }
            push @{ $retval }, $row;
        }
    }

    return $retval;
}

1;
