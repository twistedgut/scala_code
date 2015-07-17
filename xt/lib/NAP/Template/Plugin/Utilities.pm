### Package       : NAP::Template::Plugin::Utilities                         ###
# description     : A collection of utils to be used with the Template Toolkit #
#                   to use these utils put the following in your TT document:  #
#                      [% USE Utilities([list of functions to use]) %]         #
#                                                                              #
# current methods : subkeysrt - allows you to sort a hash of hashes by 1 or    #
#                               more subkeys, either numerically (nsubkeysrt)  #
#                               or alpha-numerically (subkeysrt).
#                               Usage: hashname.subkeysrt([list of keys]) or   #
#                                      hashname.nsubkeysrt([list of keys])     #

package NAP::Template::Plugin::Utilities;

use strict;
use warnings;

use base qw( Template::Plugin );


sub new {
    my ($class, $context, @args)    = @_;
    my $new_obj;
    # pointer to symbol table for this package
    my $symtab  = \%NAP::Template::Plugin::Utilities::;

    # go through each argument to load in the VMethod
    foreach ( @args ) {
        $_  = "_".$_ unless /^_/; # put an underscore on the front of the arg
        $_  .= "_init";           # put _init on the end of the arg

        if ( exists $symtab->{$_} ) {
            ## no critic(ProhibitLocalVars,ProhibitAmpersandSigils)
            local *symbol   = $symtab->{$_};
            if ( defined &symbol ) {
                # if it's in the symbol table and it is a function then call
                # the _init function to set-up the VMethod
                &symbol($context);
            }
        }
    }

    $new_obj    = bless {}, $class;

    return $new_obj;
}


### Subroutine : _subkeysrt_init                                        ###
# usage        : _subkeysrt_init($context)                                #
# description  : Used to plugin the VMethod for the appropriate data type #
#                In this case only HASH variables can use this VMethod    #
# parameters   : A reference to the Context package                       #
# returns      : nothing                                                  #

sub _subkeysrt_init {
    my $context     = shift;

    # Assign the VMethod to HASH variables
    $context->define_vmethod( hash => nsubkeysrt => \&_nsubkeysrt );    # Numeric Sort
    $context->define_vmethod( hash => subkeysrt => \&_subkeysrt );      # Alpha Sort
}

### Subroutine : _nsubkeysrt                                            ###
# usage        : Used in TT: hashname.nsubkeysrt([list_of_keynames])      #
# description  : For use in TT to sort a hash of hashes by a key or keys  #
#                of the secondary hash. NUMERIC VERSION. Just pass the    #
#                name of the keys to sort on as a paramater when you call #
#                this function and it will return a list of the primary   #
#                hash's keys in the correct order, which can be used in a #
#                FOREACH directive. To reverse the order of the list use  #
#                the .reverse VMethod as normal eg:                       #
#                           hashname.nsubkeysrt('key1','key2').reverse    #
# parameters   : The key or keys of the subhash to sort on                #
# returns      : An array of keys of the primary hash                     #

sub _nsubkeysrt {
    my ($shash,@skey)   = @_;

    # Create a new object using the Sort Package, passing in the hash and
    # keys to sort on
    my $sort    = NAP::Template::Plugin::Utilities::Sort->new($shash,@skey);
    # Numerically sort the HASH
    return $sort->nsort();
}

### Subroutine : _subkeysrt                                             ###
# usage        : Used in TT: hashname.subkeysrt([list_of_keynames])       #
# description  : For use in TT to sort a hash of hashes by a key or keys  #
#                of the secondary hash. ALPHA VERSION. Just pass the      #
#                name of the keys to sort on as a paramater when you call #
#                this function and it will return a list of the primary   #
#                hash's keys in the correct order, which can be used in a #
#                FOREACH directive. To reverse the order of the list use  #
#                the .reverse VMethod as normal eg:                       #
#                           hashname.subkeysrt('key1','key2').reverse     #
# parameters   : The key or keys of the subhash to sort on                #
# returns      : An array of keys of the primary hash                     #

sub _subkeysrt {
    my ($shash,@skey)   = @_;

    # Create a new object using the Sort Package, passing in the hash and
    # keys to sort on
    my $sort    = NAP::Template::Plugin::Utilities::Sort->new($shash,@skey);
    # Alpah-Numerically sort the HASH
    return $sort->sort();
}


### Package       : NAP::Template::Plugin::Utilities::Sort                  ###
# description     : For use with the 'subkeysrt' VMethod as defined above     #
#                   it's used to sort the HASH by using more that one KEY and #
#                   also allows checking when performing a numeric sort that  #
#                   the values are numeric. By creating an object from this   #
#                   package allows more flexibility when sorting the HASH     #
#                   such as checking the values of keys before sorting and    #
#                   multiple key sorting.                                     #
#                                                                             #
# current methods : _nsort_func - Sorts Numerically                           #
#                   _sort_func  - Sorts Alpha-Numerically                     #

## no critic(ProhibitMultiplePackages)
package NAP::Template::Plugin::Utilities::Sort;

use strict;
use warnings;

our $AUTOLOAD;

my $sort_hash;
my @sort_keys;

sub new {
    my ($class,@args)   = @_;

    $sort_hash  = shift @args;
    @sort_keys  = @args;

    # define a HASH with pointers to the sort functions
    my $sort_funcs  = {
        _sort_funcs => {
            nsort   => \&_nsort_func,
            sort    => \&_sort_func
        }
    };

    return bless $sort_funcs,$class;
}

sub AUTOLOAD { ## no critic(ProhibitAutoloading)
    my $self        = shift;
    my $name        = $AUTOLOAD;
    my $sort_funcs  = $self->{_sort_funcs};

    my @retval;

    # get the name of the function that was called
    $name   =~ s/.*://g;
    return      if ($name eq 'DESTROY');

    if (exists $sort_funcs->{$name}) {
        # if the function exists in the '_sort_funcs' hash then get the sort function and sort using it
        my $sort_func   = $sort_funcs->{$name};
        foreach ( sort $sort_func keys %$sort_hash ) {
            push @retval,$_;
        }
        return @retval;
    }

    return;
}

### Subroutine : _nsort_func                                            ###
# usage        : used as a sort function by using the sort keyword e.g:   #
#                     foreach ( sort _nsort_func keys %hash )             #
# description  : This sorts a hash of hashes using 1 or more of it's keys #
#                NUMERICALLY. Will check to see if the value of each key  #
#                is numeric before sorting on it.                         #
# parameters   : none                                                     #
# returns      : a sorted list                                            #

sub _nsort_func {
    return 0        if (!@sort_keys);
    foreach my $skey ( @sort_keys ) {
        next    if ( !exists $$sort_hash{$a}{$skey} || !exists $$sort_hash{$b}{$skey} );
        next    if ( !defined $$sort_hash{$a}{$skey} || !defined $$sort_hash{$b}{$skey} );
        next    if ( $$sort_hash{$a}{$skey} =~ /[^0-9\.\-]/ || $$sort_hash{$b}{$skey} =~ /[^0-9\.\-]/ );
        next    if ( $$sort_hash{$a}{$skey} !~ /[0-9]/ || $$sort_hash{$b}{$skey} !~ /[0-9]/ );
        next    if ( $$sort_hash{$a}{$skey} eq '' || $$sort_hash{$b}{$skey} eq '' );
        return $$sort_hash{$a}{$skey} <=> $$sort_hash{$b}{$skey} || next;
    }
}

### Subroutine : _sort_func                                             ###
# usage        : used as a sort function by using the sort keyword e.g:   #
#                     foreach ( sort _sort_func keys %hash )              #
# description  : This sorts a hash of hashes using 1 or more of it's keys #
#                ALPHA-NUMERICALLY.                                       #
# parameters   : none                                                     #
# returns      : a sorted list                                            #

sub _sort_func {
    return 0        if (!@sort_keys);
    foreach my $skey ( @sort_keys ) {
        next    if ( !exists $$sort_hash{$a}{$skey} || !exists $$sort_hash{$b}{$skey} );
        next    if ( !defined $$sort_hash{$a}{$skey} || !defined $$sort_hash{$b}{$skey} );
        return $$sort_hash{$a}{$skey} cmp $$sort_hash{$b}{$skey} || next;
    }
}

1;

__END__


=pod

=head1 NAME

NAP::Template::Plugin::Utilities - A collection of utils for TT especially adding in useful VMethods to extend functionality

=head1 SYNOPSIS

Make sure that the plugin namespace is specified in XTemplate.pm:

  Template->new(
    # ...
    PLUGIN_BASE => 'NAP::Template::Plugin',
  );

Then use the plugin in your TT templates:

  [% USE Utilities( list of VMethods to use ) %]

=head1 ADDING TO

When adding more VMethods create the function with an underscore as the prefix to it's name and also create a corresponding
init function which has the same name as the function but with an _init as a suffix. This _init function is used so that
you can assign the VMethod to different variable types: SCALAR, ARRAY or HASH so that the same VMethod can be used across
differnt types but only needs to be called once in the USE clause in your TT document.

When adding normal functions that can be used don't name them with an underscore prefix and _init suffix so that they can't
be loaded as VMethods when listed in the USE clause in the TT document.

=head1 AUTHOR

Andrew Beech C<< <andrew.beech@net-a-porter.com> >>

=cut
