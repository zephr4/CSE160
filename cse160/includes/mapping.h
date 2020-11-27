#ifndef MAPPING_H
#define MAPPING_H

typedef nx_struct mapping {
    nx_uint16_t dest; 
    nx_uint16_t nextHop;
    nx_uint16_t cost;                //cost will increment by 1, based on # of hops
}mapping;

#endif