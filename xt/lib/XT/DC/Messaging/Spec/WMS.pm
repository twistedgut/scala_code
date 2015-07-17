package XT::DC::Messaging::Spec::WMS;
use strict;
use warnings;
use NAP::Messaging::Validator;

NAP::Messaging::Validator->add_type_plugins(
    map {"XT::DC::Messaging::Spec::Types::$_"}
        qw(procid stock_status place storage_type
           rail_id tote_id pigeonhole_id carton_id
           shipment_type client hookgroup_id
      )
    );

my @version = (
    'version' => {
        'type' => '//str',
        'value' => '1.0',
    },
);

####################
# XT -> WMS messages
####################

# A type that allows the given types or nil
sub _type_or_nil { return { type => '//any', of => [ @_, '//nil' ], }; }

sub pre_advice {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'pgid' => '/nap/procid',
            'stock_status' => '/nap/stock_status',
            'channel' => '//str',
            'destination' => '/nap/place',
            'is_return' => '//bool',
            'items' => {
                'type' => '//arr',
                'length' => { 'min' => 1 },
                'contents' => {
                    'type' => '//rec',
                    'required' => {
                        'pid'          => '//int',
                        'description'  => '//str',
                        'storage_type' => '/nap/storage_type',
                        'length'       => _type_or_nil('//num'),
                        'width'        => _type_or_nil('//num'),
                        'height'       => _type_or_nil('//num'),
                        'weight'       => _type_or_nil('//num'),
                        'skus'         => {
                            'type' => '//arr',
                            'length' => { 'min' => 1 },
                            'contents' => {
                                'type' => '//rec',
                                'required' => {
                                    'sku' => '/nap/sku',
                                    'quantity' => '//int',
                                },
                                'optional' => {
                                    # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                                    'client' => '/nap/client',
                                },
                            }
                        }
                    },
                    'optional' => {
                        'photo_url' => '//str',
                    },
                }
            },
        },
        'optional' => {
            'container_id' => {
                'type' => '//any',
                'of' => [ '/nap/rail_id', '/nap/tote_id' ],
            }
        }
    }
}

sub stock_change {
    return {
        type => '//rec',
        required => {
            @version,
            what => {
                type => '//any',
                of => [
                    {
                        type => '//rec',
                        required => {
                            sku => '/nap/sku'
                        },
                        optional => {
                            pgid => '/nap/procid',
                            # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                            'client' => '/nap/client',
                        },
                    },
                    {
                        type => '//rec',
                        required => {
                            pid => '//int'
                        },
                        optional => {
                            pgid => '/nap/procid',
                        }
                    }
                ]
            },
            from => {
                type => '//rec',
                required => {
                    stock_status => '/nap/stock_status',
                    channel => '//str'
                }
            },
            to => {
                type => '//rec',
                required => {
                    stock_status => '/nap/stock_status',
                    channel => '//str'
                }
            }
        }
    }
}

# might as well be the same as stock_change
sub stock_changed {
    return {
        type => '//rec',
        required => {
            @version,
            what => {
                type => '//any',
                of => [
                    {
                        type => '//rec',
                        required => {
                            sku => '/nap/sku'
                        },
                        optional => {
                            pgid => '/nap/procid',
                            # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                            'client' => '/nap/client',
                        },
                    },
                    {
                        type => '//rec',
                        required => {
                            pid => '//int'
                        },
                        optional => {
                            pgid => '/nap/procid',
                        }
                    }
                ]
            },
            from => {
                type => '//rec',
                required => {
                    stock_status => '/nap/stock_status',
                    channel => '//str'
                }
            },
            to => {
                type => '//rec',
                required => {
                    stock_status => '/nap/stock_status',
                    channel => '//str'
                }
            }
        }
    }
}

sub shipment_request {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            'shipment_type' => '/nap/shipment_type',
            'stock_status' => '/nap/stock_status',
            'deadline' => '/nap/datetime',
            'channel' => '//str',
            'premier' => '//bool',
            'has_print_docs' => '//bool',
            'items' => {
                'type' => '//arr',
                'length' => { 'min' => 1 },
                'contents' => {
                    'type' => '//rec',
                    'required' => {
                        'sku' => '/nap/sku',
                        'quantity' => '//int',
                    },
                    'optional' => {
                        'pgid' => '/nap/procid', # to get that SKU that came from this PGID
                        # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                        'client' => '/nap/client',
                    }
                }
            }
        },
        # initial_priority will be made required when we switch IWS
        # to using the 'bump priority' fields
        optional => {
            'initial_priority'      => '//int',
            'bump_deadline'         => '/nap/datetime',
            'bump_priority'         => '//int',
            'priority_class'        => '//int',
        },
    }
}

sub shipment_cancel {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
        }
    }
}

sub shipment_reject {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            'containers' => {
                'type' => '//arr',
                'length' => { 'min' => 0 },
                'contents' => {
                    'type' => '//rec',
                    'required' => {
                        'container_id' => {
                            'type' => '//any',
                            'of' => [ '/nap/tote_id', '/nap/pigeonhole_id', '/nap/hookgroup_id' ],
                        },
                        'items' => {
                            'type' => '//arr',
                            'length' => { 'min' => 1 },
                            'contents' => {
                                'type' => '//rec',
                                'required' => {
                                    'sku'       => '/nap/sku',
                                    'quantity'  => '//int',
                                },
                                'optional' => {
                                    'pgid' => '/nap/procid',
                                    # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                                    'client'    => '/nap/client',
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


sub shipment_received {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
        }
    }
}

sub item_moved {
    return {
        type => '//rec',
        required => {
            version => { type => '//str', value => '1.0' },
            moved_id => '/nap/procid',
            from => {
                type => '//any',
                of => [
                    {
                        type => '//rec',
                        required => {
                            container_id => {
                                type => '//any',
                                of => [ '/nap/tote_id', '/nap/pigeonhole_id', '/nap/hookgroup_id' ],
                            },
                        },
                    },
                    {
                        type => '//rec',
                        required => {
                            container_id => {
                                type => '//any',
                                of => [ '/nap/tote_id', '/nap/pigeonhole_id', '/nap/hookgroup_id' ],
                            },
                            place => '/nap/place',
                        },
                    },
                    {
                        type => '//rec',
                        required => {
                            place => '/nap/place',
                        },
                    },
                    {
                        type => '//rec',
                        required => {
                            no => {
                                type => '//str',
                                value => 'where',
                            },
                        },
                    },
                ],
            },
            to => {
                type => '//any',
                of => [
                    {
                        type => '//rec',
                        required => {
                            container_id => {
                                type => '//any',
                                of => [ '/nap/tote_id', '/nap/pigeonhole_id', '/nap/hookgroup_id' ],
                            },
                            stock_status => '/nap/stock_status', # the new one
                        },
                    },
                    {
                        type => '//rec',
                        required => {
                            container_id => {
                                type => '//any',
                                of => [ '/nap/tote_id', '/nap/pigeonhole_id', '/nap/hookgroup_id' ],
                            },
                            place => '/nap/place',
                            stock_status => '/nap/stock_status', # the new one
                        },
                    },
                    {
                        type => '//rec',
                        required => {
                            place => '/nap/place',
                            stock_status => '/nap/stock_status', # the new one
                        },
                    },
                ],
            },
            items => {
                type => '//arr',
                length => { min => 1 },
                contents => {
                    type => '//rec',
                    required => {
                        sku => '/nap/sku',
                        quantity => '//int',
                    },
                    optional => {
                        # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                        client  => '/nap/client',
                        pgid => '/nap/procid', # to get that SKU that came from this PGID
                        new_pgid => '/nap/procid', # for multi-way out-sort
                    }
                }
            },
        },
        optional => {
            shipment_id => '/nap/procid',
        }
    }
}

sub shipment_packed {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            'containers' => {
                'type' => '//arr',
                'length' => { 'min' => 0 },
                'contents' => {
                    'type' => '//any',
                    'of' => [ '/nap/tote_id', '/nap/carton_id' ],
                }
            },
            spur => '//int',
        }
    }
}

sub pid_update {
    return {
        'type' => '//rec',
        'required'=> {
            @version,
            'operation' => {
                'type'=> '//any',
                'of' => [
                    { 'type' => '//str', 'value' => 'add' },
                    { 'type' => '//str', 'value' => 'delete' }
                ]
            },
            'pid'          => '//int',
            'description'  => '//str',
            'photo_url'    => '//str',
            'storage_type' => '/nap/storage_type',
            # Until we make these dimensions not-nullable in the db, we will
            # always have to cater for passing null dimensions
            'length'       => _type_or_nil('//num'),
            'width'        => _type_or_nil('//num'),
            'height'       => _type_or_nil('//num'),
            'weight'       => _type_or_nil('//num'),
        },
        optional => {
            # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
            'client' => '/nap/client',
        },
    }
}

sub shipment_wms_pause {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            'pause'      => '//bool',
        },
        'optional' => {
            'reason' => '//str',
        }
    };
}

sub route_tote {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            container_id => '/nap/tote_id',
            destination  => '/nap/place',
        }
    }
}

sub printing_done {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            printers => {
                type => '//arr',
                length => { min => 0 },
                contents => {
                    type => '//rec',
                    required => {
                        printer_name => '//str',
                        documents => {
                            type => '//arr',
                            length => { min => 1 },
                            contents => {
                                type => '//str'
                            }
                        }
                    }
                }
            }
        }
    }
}

####################
# WMS -> XT messages
####################

sub stock_received {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'pgid' => '/nap/procid',
            'items' => {
                'type' => '//arr',
                'length' => { 'min' => 1 },
                'contents' => {
                    'type' => '//rec',
                    'required' => {
                        'sku' => '/nap/sku',
                        'quantity' => '//int',
                        'storage_type' => '/nap/storage_type', # it makes more sense here
                    },
                    'optional' => {
                        # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                        'client' => '/nap/client',
                    },
                }
            }
        },
        'optional' => {
            'operator' => '//str',
        }
    }
}

sub inventory_adjust {
    return {
        type => '//rec',
        required => {
            @version,
            sku => '/nap/sku',
            stock_status => '/nap/stock_status',
            reason => '//str',
            quantity_change => '//int', # signed!
        },
        'optional' => {
            # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
            'client' => '/nap/client',
        },
    }
}

sub picking_commenced {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
        }
    };
}

sub incomplete_pick {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            'items' => {
                'type' => '//arr',
                'length' => { 'min' => 1 },
                'contents' => {
                    'type' => '//rec',
                    'required' => {
                        'sku' => '/nap/sku',
                        'quantity' => '//int', # how many were not there
                    },
                    'optional' => {
                        # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                        'client' => '/nap/client',
                    },
                }
            }
        },
        'optional' => {
            'operator' => '//str',
        },
    }
}

sub shipment_ready {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            'containers' => {
                'type' => '//arr',
                'length' => { 'min' => 0 },
                'contents' => {
                    'type' => '//rec',
                    'required' => {
                        'container_id' => {
                           'type' => '//any',
                           'of' => [ '/nap/tote_id', '/nap/pigeonhole_id', '/nap/hookgroup_id' ],
                        },
                        'items' => {
                            'type' => '//arr',
                            'length' => { 'min' => 1 },
                            'contents' => {
                                'type' => '//rec',
                                'required' => {
                                    'sku' => '/nap/sku',
                                    'quantity' => '//int',
                                },
                                optional => {
                                    'pgid' => '/nap/procid', # they always know, they always tell, we rarely care
                                    # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                                    'client' => '/nap/client',
                                }
                            }
                        }
                    },
                    optional => {
                        place => '/nap/place',
                    },
                }
            }
        },
    };
}

sub shipment_refused {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            'unavailable_items' => {
                'type' => '//arr',
                'length' => { 'min' => 1 },
                'contents' => {
                    'type' => '//rec',
                    'required' => {
                        'sku' => '/nap/sku',
                        'quantity' => '//int',
                    },
                    'optional' => {
                        'pgid' => '/nap/procid', # they always know, they always tell, we rarely care
                        # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
                        'client' => '/nap/client',
                    }
                }
            }
        }
    };
}

sub tote_routed {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            container_id => '/nap/tote_id',
        }
    }
}

sub ready_for_printing {
    return {
        'type' => '//rec',
        'required' => {
            @version,
            'shipment_id' => '/nap/procid',
            'pick_station' => '//int',
        }
    }
}

sub moved_completed {
    return {
        type => '//rec',
        required => {
            version => { type => '//str', value => '1.0' },
            moved_id => '/nap/procid',
        }
    }
}

sub inventory_adjusted {
    return {
        type => '//rec',
        required => {
            @version,
            sku => '/nap/sku',
            stock_status => '/nap/stock_status',
        },
        optional => {
            # TODO: Once IWS is aware of 'client' make it required (WHM-2471)
            'client' => '/nap/client',
        },
    }
}

1;
