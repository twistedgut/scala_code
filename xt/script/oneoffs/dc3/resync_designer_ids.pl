#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( schema_handle );
use Data::Dump qw( pp );
use Getopt::Long;

my $host = 'fulcrum-napapac.dave';
my $user = 'www';
my $pass = 'www';
my $db   = 'xt_central';
my $commit;
my $help;

my $unused_marker = '[UNUSED] ';
my $manual_map = {
    'Burberry' => 'Burberry_Accessories',
};

GetOptions(
    'host=s'        => \$host,
    'user=s'        => \$user,
    'password=s'    => \$pass,
    'database=s'    => \$db,
    'help+'         => \$help,
    'commit+'       => \$commit,
);

if ($help) {
    print <<END;

  $0 --host fulcrum-napapac.dave --user jason --password secret
        --database xt_central --help --commit

END
    exit;
}

my $f_dbh = Fulcrum::Schema->connect(
    "dbi:Pg:database=$db;host=$host",
    $user,
    $pass
);

my $x_dbh            = schema_handle;
my $f_designer       = $f_dbh->resultset('Designer');
my $x_designer       = $x_dbh->resultset('Public::Designer');
my $x_purchase_order = $x_dbh->resultset('Public::PurchaseOrder');
my $x_product        = $x_dbh->resultset('Public::Product');

$x_dbh->txn_do(sub {

    # 1. find designers found in po/pid and create mapping
    #    - move unknown designers to the end
    # 2. import fulcrum designers
    # 3. update with new designer ids
    # 4. delete unused designers
    # 5. import mising designer_channel data from fulcrum

    my $mapping = xt_create_mapping();
    # old_id => {
    #        info => {
    #           name    => '',
    #           url_key => '',
    #        },
    #        po => [],
    #        pid => [],
    #        new_id => '',
    #        not_found => 1,
    #        multiple => 1,
    #    }

    xt_update_designer_table();
    xt_update_with_new_designer_ids($mapping);

    xt_delete_unused_designers();

    xt_sync_designer_channel();

    if ($commit) {
        $x_dbh->txn_commit;
        print "\n\n  Committed. The damage is done.\n\n";
    } else {
        $x_dbh->txn_rollback;
        print "\n\n  ROLLED BACK! Use --commit to REALLY do it.\n\n";
    }

});

sub xt_delete_unused_designers {
    my $set = $x_designer->search({
        url_key => {
            ilike => $unused_marker. '%',
        },
    });

    print "  DELETING\n";
    foreach my $row ( $set->all ) {
        print "  ==> ". $row->designer ." (". $row->url_key .")\n";
        $row->delete;
    }
    print "\n";
}

sub xt_create_mapping {
    my %mapping;
    my $used_designers;
    my $set = $x_purchase_order->search({},{ order_by => 'id' });

    while (my $po = $set->next) {
        my $designer = $po->designer;

        add_designer(
            \%mapping,
            $designer,
            'po',
            $po->id,
        );

    }

    $set = $x_product->search({},{ order_by => 'id' });
    while (my $pid = $set->next) {
        my $designer = $pid->designer;

        add_designer(
            \%mapping,
            $designer,
            'pid',
            $pid->id,
        );

    }

    my $mapping = \%mapping;
    foreach my $key (keys %mapping) {
        my $rec = $mapping{$key};
        print " ==> [". $rec->{info}->{name} ."] ("
            .$rec->{info}->{url_key} .")\n";

        if ($mapping->{$key}->{not_found}) {
            print "  NOT FOUND\n";
        } elsif ($mapping->{$key}->{multiple}) {
            print "  MULTIPLE FOUND\n";
        }
        if ($mapping->{$key}->{pid}) {
            print "  PID:". join(',',@{$mapping->{$key}->{pid}}) ."\n";
        }
        if ($mapping->{$key}->{po}) {
            print "  PO:". join(',',@{$mapping->{$key}->{pid}}) ."\n";
        }

        print "\n";
    }
    print "\n";

    return \%mapping;
}

sub add_designer {
    my($mapping,$designer,$rec,$id) = @_;

    # keep the xt info for matching
    if (!defined $mapping->{$designer->id}->{info}) {
        $mapping->{$designer->id}->{info} = {
            name => $designer->designer,
            url_key => $designer->url_key,
        }
    }

    # do we have tried looking it up in fulcrum
    if (!defined $mapping->{$designer->id}->{new_id}
        && !$mapping->{$designer->id}->{not_found}
        && !$mapping->{$designer->id}->{multiple}
        ) {
        # override with a manual mapping for the unknown designers
        my $url_key = $manual_map->{$designer->url_key}
            ? $manual_map->{$designer->url_key}
            : $designer->url_key;

        if ($url_key ne $designer->url_key) {
            print " ==> remapped ". $designer->url_key ." to $url_key\n";
        }

        my $new_designer = $f_designer->search({
            url_key => { 'ILIKE' => $url_key },
        });

        if ($new_designer->count == 1) {
            $mapping->{$designer->id}->{new_id} = $new_designer->first->id;
        } elsif ($new_designer->count == 0) {
            $mapping->{$designer->id}->{not_found} = 1;
        } else {
            $mapping->{$designer->id}->{multiple} = 1;
        }
    }

    # add the id the record list
    push(
        @{ $mapping->{$designer->id}->{$rec} },
        $id
    );
}

sub xt_update_designer_table {
    my($mapping) = @_;
    # rename the unused ones so we're save to insert
    foreach my $row ( $x_designer->all ) {
        if (!defined $mapping->{$row->id}) {
            $row->update({
                designer    => $unused_marker. $row->designer,
                url_key     => $unused_marker. $row->url_key,
            });
        }
    }
    foreach my $f_row ( $f_designer->all ) {
        # This loop essentially copies Fulcrum data into XTracker.

        $x_designer->update_or_create({
            id       => $f_row->id,
            designer => $f_row->name,
            url_key  => $f_row->url_key,
        });

    }

}

sub xt_update_with_new_designer_ids {
    my($mapping) = @_;

    foreach my $designer (values %{$mapping}) {
        if (!defined $designer->{new_id}) {
            print "SKIPPING: ". $designer->{info}->{name}
                ."(". $designer->{info}->{url_key} .")\n";
            next;
        }
        # This updates the child tables with the new designer ID's.
        # products
        if (defined $designer->{pid}) {
            foreach my $pid (@{$designer->{pid}}) {
                $x_product->find( $pid )->update({
                    designer_id => $designer->{new_id},
                });
            }
        }

        # purchase orders
        if (defined $designer->{po}) {
            foreach my $po_id (@{$designer->{po}}) {
                $x_purchase_order->find( $po_id )->update({
                    designer_id => $designer->{new_id},
                });
            }
        }

    }

}

sub xt_sync_designer_channel {

    print "SYNCING designer.channel\n\n";

    # For the purpose of this script it doesn't matter what page id we use, as
    # they'll be updated to correct value later. So for now we'll just use the
    # lowest one.
    my $page = $x_dbh->resultset('WebContent::Page')
        ->search( undef, { order_by => { '-desc' => 'id' } } )
        ->first;

    print " - Using page [" . $page->name . "] (id=" . $page->id . ")\n";

    # Get all the designer.channel records from Fulcrum for NAP-APAC.
    my $source = $f_dbh->resultset('DesignerChannel')
        ->search( {
            channel_id => { '-in' => [
                $x_dbh->resultset('Public::Channel')
                    ->get_column('id')
                    ->all
            ] },
        } );

    my $destination = $x_dbh->resultset('Public::DesignerChannel');
    my $initial_count = $destination->count;

    print " - Found " . $source->count . " records in Fulcrum and $initial_count records in XTracker\n";

    # For each Designer Channel record in Fulcrum, attempt to find a matching
    # row in XTracker (based on designer_id, via unique constraint). If
    # not found, create a new one.
    while ( my $row = $source->next ) {

        $destination->find_or_create( {
            designer_id         => $row->designer_id,
            page_id             => $page->id,
            website_state_id    => $x_dbh->resultset('Designer::WebsiteState')
                                        ->find( {
                                            state => $row->visibility->name
                                        } )
                                        ->id,
            channel_id          => $row->channel_id,
            description         => $row->description,
            description_is_live => 0,
        } );

    }

    print " - Created " . ( $destination->count - $initial_count ) . " new rows in XTracker\n";
    print "\nDONE SYNCING designer.channel\n";

}

# =================================================

package Fulcrum::Schema;

use base 'DBIx::Class::Schema::Loader';

BEGIN {
    __PACKAGE__->loader_options(
        db_schema  => '%',
        naming     => 'current',
    );
}

