package XT::Cache::Function;

use strict;
use warnings;
use feature     'state';

=head1 NAME

XT::Cache::Function

=head1 SYNOPSIS

# Default
    use XT::Cache::Function     qw( cache_a_function cache_and_call_method );

    cache_a_function( 'slow_function' );
    my $result  = slow_function();

    $result     = cache_and_call_method( $object, 'slow_method', any, params, ... );


# for functions
    use XT::Cache::Function         qw( cache_a_function );

    cache_a_function( 'slow_function' );
    $value = slow_function( { foo => 'bar' } );             # result will be cached for arguments passed
    ...
    $another_value = slow_function( { foo => 'bar' } );     # uses cached result instead of actually calling the function

    # CONTEXT is important and doesn't use the same Cached Results
    $SCALAR = slow_function( 1 );       # these two will NOT use the same cached results and
    @LIST   = slow_function( 1 );       # therefore can return two completely different values


# for object methods
    use XT::Cache::Function         qw( cache_and_call_method );

    $obj    = MyObject->new();
    # want to cache calls to '$obj->slow_method( { foo => 'bar' } )'
    $value = cache_and_call_method( $obj, 'slow_method', { foo => 'bar' } );            # result will be cached for arguments passed
    ...
    $another_value = cache_and_call_method( $obj, 'slow_method', { foo => 'bar' } );    # uses cached result and won't call the method

# for DBIC Objects the Id of the record (if it has one) will be used to
# distinguish between different records when calling the same method
    my @recs    = $rs->search( { status_id => 3 } )->all;
    $value1     = cache_and_call_method( $recs[0], 'slow_method' );
    $value2     = cache_and_call_method( $recs[1], 'slow_method' );     # will not give the same result as the call above did


# for methods in classes
    package Foo;

    use XT::Cache::Function     qw( cache_a_method );

    sub method {
        ...
    }
    cache_a_method('method');

    1;

    use Foo;
    $object = Foo->new;
    $object->method;        # 'method' will be cached


# to Stop Caching
    use XT::Cache::Function         qw( :stop );

    # then use
    stop_caching_a_function( 'slow_function');      # will Stop Caching 'slow_function' and Empties the Cache

    # or for Methods and Functions
    stop_all_caching();                             # will Stop Caching all Functions and Methods that have
                                                    # previously been Cached and will also Empty the Cache


# to generate a Key for parameters, if you want to use your own
# way of caching the parameters passed to functions and methods
    use XT::Cache::Function         qw( :key );

    # for a normal Function
    $key = generate_cache_key( @params_to_cache );

    # for Methods on an Object
    $key = generate_method_cache_key( $object, 'method_name', @params_to_cache );

=head2 WARNING

    There is no Cache Expiration functionality implemented as yet so please use the ':stop'
    functions to clear the Cache.


=head1 DESCRIPTION

This will allow the Caching of the Result of calls to either Functions or Methods based on the Arguments
passed to them, thus allowing repetative calls to Slow Functions/Methods to be quicker and should speed up
your Application.

=head1 TODO

Cache Expiration

There is currently NO Cache Expiration functionality implemented which means the ':stop' functions
should be used to clear the Cache, this needs to be done in the future.

=cut

BEGIN {
    use Exporter    qw( import );

    our @EXPORT_OK      = ( qw( cache_a_function cache_a_method cache_and_call_method ) );
    our %EXPORT_TAGS    = (
        key             => [ qw( generate_cache_key generate_method_cache_key ) ],
        stop            => [ qw( stop_caching_a_function stop_all_caching ) ],
    );
    Exporter::export_ok_tags( qw(
        key
        stop
    ) );
}

use Carp;

use Memoize             qw( memoize unmemoize flush_cache );

use Scalar::Util        qw( blessed );
use JSON;


# store a list of all cached functions
my %cached_functions;

=head1 FUNCTIONS

=head2 cache_a_function

=over 3

    $code_ref = cache_a_function( 'function_to_cache' );
    function_to_cache( arguments );

    # please note CONTEXT is important these two
    # calls will not return the same cached result
    $scalar = function_to_cache( 1 );
    @array  = function_to_cache( 1 );

Once this has been called with the name of a function you wish to Cache then for every call
of that function the Cache will be checked to see if the arguments have been passed before
by generating a key for them and if that key has been cached then the result from the Cache
will be returned instead of executing the function.

See 'generate_cache_key' on how the arguments will be compared.

What is returned is the CODE Reference for the function that has replaced the original function
in the Symbol table, it is NOT advised to use this Reference to actually call your function.

=back

=cut

sub cache_a_function {
    my $function    = _get_function_name( shift );

    # store that this function has been Cached, used by 'stop_all_caching'
    $cached_functions{ $function }  = $function;

    return memoize( $function,
        # Memoize calls this function to get a key for the arguments
        NORMALIZER  => \&generate_cache_key,
    );
}

=head2 cache_a_method

=over 3

    package Foo:

    sub method_to_cache {
        ...
    }
    $code_ref = cache_a_method( 'method_to_cache' );

    1;

    use Foo;

    $object = Foo->new;
    $object->method_to_cache( arguments );

    # please note CONTEXT is important these two
    # calls will not return the same cached result
    $scalar = $object->method_to_cache( 1 );
    @array  = $object->method_to_cache( 1 );

Once this has been called with the name of a method you wish to Cache then for every call
of that method the Cache will be checked to see if the arguments have been passed before
by generating a key for them and if that key has been cached then the result from the Cache
will be returned instead of executing the method.

See 'generate_method_cache_key' on how the arguments will be compared.

What is returned is the CODE Reference for the method that has replaced the original method
in the Symbol table, it is NOT advised to use this Reference to actually call your method.

=back

=cut

sub cache_a_method {
    my $function    = _get_function_name( shift );

    # store that this method has been Cached, used by 'stop_all_caching'
    $cached_functions{ $function }  = $function;

    return memoize( $function,
        # Memoize calls this function to get a key for the arguments
        NORMALIZER  => \&generate_method_cache_key,
    );
}

=head2 stop_caching_a_function

=over 3

    $code_ref = stop_caching_a_function( 'function_that_was_being_cached' );

After a call to 'cache_a_function' this will then stop the Caching process and from then
on the function will be executed normally for every call.

It returns a CODE Reference to the function that was being Cached, it's NOT advised to use
this reference to actually call your function.

This will also Empty the Cache so if you subsequently want to start Caching the same function
again it will start with an Empty Cache.

=back

=cut

sub stop_caching_a_function {
    my $function    = _get_function_name( shift );

    my $ref = eval {
        # this eval will fail if $function was NOT
        # actually Memoized, but there's no need to care
        flush_cache( $function );
        unmemoize( $function );
    };

    return $ref;
}

=head2 cache_and_call_method

=over 3

    use ObjectName;

    my $obj = ObjectName->new();

    # want to cache calls to '$obj->method_name'
    $method_return_value = cache_and_call_method( $obj, 'method_name', arguments_passed_to_method, etc, etc ... );

    # please note CONTEXT is important these two
    # calls will not return the same cached result
    $scalar = cache_and_call_method( $obj, 'method_name', 1 );
    @array  = cache_and_call_method( $obj, 'method_name', 1 );

If you want to Cache calls to Methods on Objects then you have to call this function everytime you
wish to call the method. You pass to it the instantiated Object, followed by the name of the Method
you wish to call and then any arguments that you want to pass to the Method. When you call this
function a key will be generated that represents all of the arguments (including $obj and 'method_name')
if this key has been seen before the result from the cache will be returned without actually calling the
method.

See 'generate_method_cache_key' on how the arguments will be compared.

=back

=cut

# this is actually the function that gets cached by Memoize it
# expects to be passed an Object, Method Name as the first two
# params and these are then used to call the Method for the Object
sub _method_wrapper {
    my ( $obj, $method_name, @params )  = @_;
    return $obj->$method_name( @params );
};
# will hold the CODE Reference to the Memoized version of the above
my $_cached_method_wrapper_ref;

sub cache_and_call_method {
    my ( $obj, $method_name, @params )  = @_;

    $_cached_method_wrapper_ref //= memoize( '_method_wrapper',
        # Memoize calls this function to get a key for the arguments
        NORMALIZER  => \&generate_method_cache_key,
    );
    # store that this function has been Cached, used by 'stop_all_caching'
    $cached_functions{'_method_wrapper'} = __PACKAGE__ . '::_method_wrapper'
                    if ( !exists $cached_functions{'_method_wrapper'} );

    # call the Memoized version of the '_method_wrapper' function
    return $_cached_method_wrapper_ref->( $obj, $method_name, @params );
}

=head2 generate_cache_key

=over 3

    $json_string = generate_cache_key( @params );

This will Return a Key for the Parameters that were passed in so that they
can be used by a Cache to check if a function has already been called with
the same Parameters.

It will firstly represent the Parameters in a JSON string (in utf8). The JSON
object used has the 'allow_blessed' flag set which means any Objects seen will
be replaced with the word 'null', it also has the 'canonical' flag on which
means any HASH keys encountered will be sorted first so that they will always
match future calls with the same data even if it's presented in a different sequence.

=back

=cut

sub generate_cache_key {
    my @params  = @_;

    return _get_json()->encode( \@params );
}

=head2 generate_method_cache_key

=over 3

    $json_string = generate_method_cache_key( $obj, 'method_name', @params );

This will Return a Key for the Parameters that were passed in but for the use by
'call_and_cache_method' where the first parameter is expected to be an Object.

The first parameter has to be a blessed Object otherwise it will throw a FATAL error.

The Object will not be part of the Arguments that are used to generate the key, instead
if the Object can support an 'id' method (such as DBIC Objects) then a call to this will
be made and the result prepended to the argument list, then the Class Name of the Object
will also be prepended to the argument list meaning that the arguments that are about to
be cached will have the Class Name of the Object followed by the Id of the Object (or
record Id for DBIC objects) then the Method Name and then any parameters to be passed to
that Method.

Finally 'generate_cache_key' will be called with the new arguments to actually generate the key.

Because an Id and the Class Name is included in the argument list it means that for DBIC
Objects of the same Class which represent different Records in a Table can have the same
Method called against them and because their Ids won't be the same different cached results
will be returned meaning you don't have to worry about clearing out the Cache when you
have a new Record to call the Method against.

=back

=cut

sub generate_method_cache_key {
    my @params  = @_;

    my $obj = shift @params;
    if ( !blessed( $obj ) ) {
        confess "First parameter passed is NOT an Object to '" . __PACKAGE__ . "::generate_method_key'";
    }

    if ( $obj->can('id') ) {
        # put a unique Id for the Object (or record for DBIC objects)
        # at the start of the parameters to distinguish this Object
        # from others of the same Class
        unshift @params, $obj->id;
    }
    unshift @params, ref( $obj );

    return generate_cache_key( @params );
}

=head2 stop_all_caching

=over 3

    stop_all_caching();

This will Stop the Caching of all Functions that have been cached
using 'cache_a_function' and all Methods that have been cached

The Cache will be cleared meaning if you wish to subsequently cache
a Function or Method they will start with an Empty Cache.

=back

=cut

sub stop_all_caching {
    # need to set the method wrapper ref to 'undef' otherwise
    # subsequent method caching won't behave properly
    $_cached_method_wrapper_ref = undef;

    foreach my $key ( keys %cached_functions ) {
        my $function = delete $cached_functions{ $key };
        stop_caching_a_function( $function );
    }

    return;
}


# helper to return the name of the function
# with its package name prefix added if needed
sub _get_function_name {
    my $function    = shift;

    if ( ref( $function ) ne 'CODE' || $function !~ /::/ ) {
        # special case for Method Caching
        return $function        if ( $function eq __PACKAGE__ . '::_method_wrapper' );

        # find the first caller which didn't come from THIS package
        # only go 10 deep, don't bother looking after that
        my $caller;
        WHO_CALLED:
        foreach my $call_frame ( 1..10 ) {
            $caller = caller( $call_frame );
            last WHO_CALLED     if ( $caller && $caller ne __PACKAGE__ );
        }
        if ( !$caller ) {
            confess "Couldn't find Calling Package for function '${function}' in '" . __PACKAGE__ . "::_get_function_name'";
        }

        # prefix the function with the Caller's package name
        $function   = "${caller}::${function}";
    }

    return $function;
}

# helper to return an instance of JSON, this uses
# a 'state' variable meaning that each call to this
# function won't result in a new JSON object being
# instantiated
sub _get_json {
    state $json = JSON->new
                        ->allow_unknown
                        ->allow_blessed
                        ->convert_blessed
                        ->canonical;
    return $json;
}

1;
