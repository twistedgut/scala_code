# path_properties.awk -- operate on XT path properties file

# Usage: awk -f path_properties.awk --rpm_attr | --print_path | --check {properties_file_if_not_stdin}

# Options:
#    --rpm_attr  :  print rpm %attr entry to STDOUT
#    --print_path:  print the the path field to STDOUT
#    --check     :  check the path property records, output to STDERR


BEGIN {
    # Separate fields on newline and records on empty string.
    # Allows multi-line path records separated by empty lines
    FS="\n"; RS="";
}

BEGIN {
    # Parse option and remove from file processing list
          if (ARGV[1] == "--rpm_attr")   { rpm_attr++    }
     else if (ARGV[1] == "--print_path") { print_path++  }
     else if (ARGV[1] == "--check")      { check_props++ }
     else                                { usage()       }

     delete ARGV[1]
}

BEGIN {
    # Set up expected path record fields
    expected["path"]           \
    = expected["permissions"]  \
    = expected["user"]         \
    = expected["group"] = 1
}

{
    # Main record loop
    # Attempt to parse path properties for a single record block
    for(i=1;i<=NF;i++) {
        if($i ~ /.*_PATH/)  { split($i,FIELD," "); props["path"]         = FIELD[2]; }
        if($i ~ /.*_PERM/)  { split($i,FIELD," "); props["permissions"]  = FIELD[2]; }
        if($i ~ /.*_USER/)  { split($i,FIELD," "); props["user"]         = FIELD[2]; }
        if($i ~ /.*_GROUP/) { split($i,FIELD," "); props["group"]        = FIELD[2]; }
    }

    # Main action
         if(rpm_attr)    { print_attr()           }
    else if(print_path)  { print_property("path") }
    else if(check_props) { check_property_recs()  }

    # Clear arrays for next record
    for ( type in expected ){
        if( type in props ){ delete props[type] }
        if( type in err   ){ delete err[type]   }
    }
}

END {
    if(file_error == 1){
        exit 1
    }
}

function usage() {
    e = "usage: awk -f path_properties.awk --rpm_attr | --print_path | --check {properties_file_if_not_stdin}"
    print e | "cat 1>&2"
    exit 1
}

function print_attr() {
    # Print out formatted RPM %attr entry
    printf "%%attr(%s, %s, %s) %%dir %s\n"     \
        , props["permissions"]                 \
        , props["user"]                        \
        , props["group"]                       \
        , props["path"]
}

function print_property (p) {
    # Print a single property value
    print props[p]
}

function check_property_recs() {
    # Run through path records and report incomplete entries to STDERR
    for (type in expected){
        if( type in props ) { ; }
        else {
            err[type]  = 1
            file_error = 1
        }
    }

    if(length(err) > 0){
        errstr = "[Path properties error]"
        printf "%s Record %s\n", errstr, FNR | "cat 1>&2"
        for (type in err){
            printf "%s > Missing %s\n", errstr, type | "cat 1>&2"
        }
    }
}
