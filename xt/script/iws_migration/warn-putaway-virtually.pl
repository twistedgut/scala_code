#!/opt/xt/xt-perl/bin/perl
#
# FOR MIGRATION PURPOSES ONLY!  NOT FOR NORMAL USE ON A LIVE SYSTEM!!
#
# See DCEA-1389 for more details.
#
# The explanatory comment from that ticket is duplicated here:
#
#   For the live switch-over, we need to complete all putaway processes.
#
#   Those that have corresponding physical items will be put away normally, by the warehouse staff.
#
#   Those that don't, will have to be put away "virtually", and the
#   stock thus created will have to be destroyed (adjusted
#   down). Since there are a few hundred of these processes, we need a
#   program.
#
#   A way to see all the processes that need put away is:
#
#   > /tmp/putaway.lst perl -Mlib=lib \
#        -MXTracker::Stock::GoodsIn::Putaway \
#        -MData::Dump=pp <<EOF
#   print pp XTracker::Stock::GoodsIn::Putaway::get_putaway_process_groups(
#   XTracker::Database::get_database_handle({
#      name=>"xtracker_schema",type=>"transaction"
#   })
#   ,0)
#   EOF
#
#   The program should:
#
#       * for each process group:
#             o complete the put away, creating stock in some predefined location ("GI" seems sensible)
#             o adjust the stock down, with a note saying where the stock came from
#
#   To implement the first part, we can re-use the code from the stock_received consumer controller. The second part is easier.
#
#   Yes, we adjust the stock after each put away, because we want to
#   join the adjustment with the delivery / return / out-of-quarantine / whatever.
#
#   At the very least, the note should read "missing items from
#   process group $pgid"; additional information
#   (like, "delivery $id", "return $return_id for shipment $shipment_id" and the like)
#   welcome but not strictly required.
#
#   Pete did some implementation via WWW::Mechanize, but it was quite hard to make it work right.
#
#

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Test::XTracker::Data ();
use Test::XTracker::MessageQueue ();
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
                                      :authorisation_level
                                      :flow_status
                                      :stock_process_status
                                      :stock_action
                              );
use XTracker::Comms::FCP ();
use XTracker::Database::Logging ();
BEGIN {
    # let's disable the functions that talk to the web db, or log
    # stuff related to the web db: these putaways won't affect it
    ## no critic(ProhibitMultiplePackages)
    package XTracker::Comms::FCP;{
        use Perl6::Export::Attrs;
        no warnings 'redefine';
        sub update_web_stock_level :Export() {}
        sub amq_update_web_stock_level :Export() {}
    }
    package XTracker::Database::Logging;{
        use Perl6::Export::Attrs;
        no warnings 'redefine';
        sub log_pws_stock :Export() {}
    }
}
use XTracker::Stock::GoodsIn::Putaway;
use XTracker::Database::StockProcessCompletePutaway qw( complete_putaway );

# some useful DB-related stuff...

my $schema = Test::XTracker::Data->get_schema;
my $dbh = $schema->storage->dbh;

my $virtual_putaway_location_name = 'GI';

my $putaway_location = $schema->resultset('Public::Location')->find({ location => $virtual_putaway_location_name });

die "No Virtual Putaway location '$virtual_putaway_location_name'\n" unless $putaway_location;

warn "$virtual_putaway_location_name contains stock, shouldn't proceed"
    if ($putaway_location->quantities->get_column('quantity')->sum||0) > 0;

my $groups_to_putaway = XTracker::Stock::GoodsIn::Putaway::get_putaway_process_groups( $schema, 0 );

use Data::Dump 'pp';
print pp $groups_to_putaway;

exit 0;

