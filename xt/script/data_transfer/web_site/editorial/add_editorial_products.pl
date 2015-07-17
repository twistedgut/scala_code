#!/opt/xt/xt-perl/bin/perl

package main;

use strict;
use warnings;
use Carp;
use Perl6::Say;
#use Perl6::Slurp;
use Getopt::Long;
use Data::Dump qw( pp );
use Fatal qw( open close );

use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( get_database_handle );

run() unless caller();


sub run {

    my $category = undef;
    my $infile   = undef;
    GetOptions( 'cat=s' => \$category, 'file=s' => \$infile );

    croak unless defined $category && defined $infile;

    unless( $category =~ m/HOME/ || $category =~ m/RBD/ ){  
        $category =~ s{_}{\/}g;
    }

    # prepare db handle and statements 
    my $dbh_fcp = get_database_handle( { name => 'Web_Live_NAP', type => 'transaction' } );
    #my $dbh_fcp = get_database_handle( { name => 'Web_DC2_Live_NAP', type => 'transaction' } );

    my $qry = "insert into searchable_product_category values ( ?, ? ,0, current_timestamp(), 'SYSTEM',  current_timestamp(), 'SYSTEM', 0);";

    my $sth = $dbh_fcp->prepare($qry);
    
    # load the products file
    open my $file, '<', $infile;
    
    while ( my $product = <$file> ){   
        chomp $product;
        say "Trying $product for $category";
       eval{
          $sth->execute( $product, $category );
          
        };
        if($@){
          say "Failed $product";
        }
    }

    $dbh_fcp->commit();
    $dbh_fcp->disconnect();
}


__END__
