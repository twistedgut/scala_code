#!/opt/xt/xt-perl/bin/perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

=head1 NAME

add_new_sizes_to_size_scheme.pl

=head1 SYNOPSIS

To add sizes to an existing size scheme:
add_new_sizes_to_size_scheme.pl --size_scheme "Size Scheme" \
                                --sizes "Size1" --sizes "Size2"

To add a new size scheme and corresponding sizes:
add_new_sizes_to_size_scheme.pl --size_scheme "Size Scheme" \
                                --sizes "Size1" --sizes "Size2"\
                                --add-sizescheme --prefix "Prefix"

=head1 DESCRIPTION

This script adds new sizes to an existing size scheme.
Alternatively, it can also be used to add a new size
scheme with required sizes and prefix.

It takes a size scheme and its sizes to be added as its
input and results in associating those sizes with the
SizeScheme provided.

=cut

use lib '/opt/xt/deploy/xtracker/lib';
use lib '/opt/xt/deploy/xtracker/lib_dynamic';

use NAP::policy "tt";
use DBI;
use Getopt::Long;
use Pod::Usage;
use XTracker::Database 'xtracker_schema';
use XTracker::Logfile  'xt_logger';

my $size_scheme;
my @sizes;
my $add_ss;
my $prefix;

GetOptions
    ("size_scheme=s"       => \$size_scheme,
     "sizes=s@"            => \@sizes,
     "add-sizescheme"      => \$add_ss,
     "prefix=s"            => \$prefix,
    );

pod2usage(1) if ( !$size_scheme || !(@sizes) );

xt_logger->info("Running LDH - add_new_sizes_to_size_scheme.pl to add new sizes for $size_scheme ");

# Get Schema
my $schema = xtracker_schema || die print "Error: Unable to connect to DB";

# Check if Size Scheme exists
my $get_size_scheme_id = $schema->storage->dbh->prepare('select id from size_scheme where name = ?');

$get_size_scheme_id->execute($size_scheme) or die "Can't execute SQL: ", $get_size_scheme_id->errstr(), "\n";

my $size_scheme_id = $get_size_scheme_id->fetchrow_array();

unless ( $size_scheme_id ) {
     # See if we need to add a new size scheme
     if($add_ss) {
         my $add_size_scheme = $schema->storage->dbh->prepare('insert into size_scheme(name,short_name)
                                                                values (?,?)'
                                                             );
         $prefix = '' unless $prefix; # this is due to the not null constraint on short name for size scheme
         $add_size_scheme->execute($size_scheme, $prefix) or die "Can't execute SQL: " , $add_size_scheme->errstr(), "\n";

         say "Added Size Scheme : $size_scheme \n"

     } else {
            die "Size Scheme $size_scheme NOT found..\nMake sure you enter the exact Size Scheme Name.\n Exiting!!! \n"
       }

} else {
       say "SizeScheme - $size_scheme Found. \nNow adding sizes "
  }

# Fetch the id of the newly added size scheme
$get_size_scheme_id->execute($size_scheme) or die "Can't execute SQL: ", $get_size_scheme_id->errstr(), "\n";

$size_scheme_id = $get_size_scheme_id->fetchrow_array();

# Ensure that the sizes to be added do not exist already
my $get_size = $schema->storage->dbh->prepare('select size
                                               from size_scheme_variant_size ssvs
                                               join size s on ssvs.size_id = s.id
                                               where size_scheme_id = ?');

$get_size->execute($size_scheme_id) or die "Can't execute SQL: ",  $get_size->errstr(), "\n";

# We'll process only the new sizes

while (my $existing_size = $get_size->fetchrow_array){
    for my $i (0..$#sizes) {
        if($sizes[$i] eq $existing_size) {
            say "Size $existing_size already exists for $size_scheme ";
            splice (@sizes,$i,1);
        }
    }
}

# Exit in case of no new sizes
if ( scalar @sizes < 1 ) {
    die "Nothing to add..Exiting!! "
} else {
       # fetch the starting position to add
       my $get_position = $schema->storage->dbh->prepare('select max(position)+1
                                                          from size_scheme_variant_size
                                                          where size_scheme_id = ? '
                                                        );

       $get_position->execute($size_scheme_id) or die "Can't execute SQL: ", $get_position->errstr(), "\n";

       # Since we have multiple sizes with the same name
       # prepare to fetch the size_id of the newest one
       my $get_max_size_id = $schema->storage->dbh->prepare('select max(id)
                                                             from size s
                                                             where s.size = ? '
                                                           );
       # Due to some sequence weirdness in live dbs,
       # we need to add the size scheme variant size record with next id
       my $get_next_id= $schema->storage->dbh->prepare('select max(id)+1
                                                        from size_scheme_variant_size'
                                                      );


       # prepare to add new size to size scheme
       my $add_size_data_to_size_scheme = $schema->storage->dbh->prepare('insert into size_scheme_variant_size
                                                                         (id, size_scheme_id,size_id,designer_size_id,position)
                                                                         values (?,?,?,?,?)'
                                                                        );

       # prepare to insert new size in size table
       my $add_size = $schema->storage->dbh->prepare('insert into size(size)
                                                      values (?)'
                                                       );


       # Now add new sizes to the size scheme
       foreach my $new_size (@sizes){
           xt_logger->info("Running LDH - Now adding size: $new_size to $size_scheme");
           $get_next_id->execute() or die "Can't execute SQL: ", $get_next_id->errstr(), "\n";
           $get_max_size_id->execute($new_size) or die "Can't execute SQL: ", $get_max_size_id->errstr(), "\n";
           $get_position->execute($size_scheme_id) or die "Can't execute SQL: ", $get_position->errstr(), "\n";
           my $position = $get_position->fetchrow_array();
           # For cases where we are adding new sizes
           # Set the starting position

           $position = 1 if not ( $position );

           my $size_id = $get_max_size_id->fetchrow_array();
           my $id = $get_next_id->fetchrow_array();

           unless ( $size_id ){
                # Insert the new size in size table and get its id
                $add_size->execute($new_size) or die "Can't execute SQL statement: ", $add_size->errstr(), "\n";
                $get_max_size_id->execute($new_size) or die "Can't execute SQL statement: ", $get_max_size_id->errstr(), "\n";
                $size_id = $get_max_size_id->fetchrow_array();
           }

           $add_size_data_to_size_scheme->execute($id, $size_scheme_id, $size_id,$size_id, $position) or die "Can't execute SQL statemnt:", $add_size_data_to_size_scheme->errstr(),"\n";

           say "Added Size :: $new_size to $size_scheme";
       }
}
## We're all Done
