#ifndef NEIGHBOR_H
#define NEIGHBOR_H

typedef nx_struct Neighbor {
    nx_uint16_t neighborAddr;
    nx_uint16_t NDsrc;
    nx_uint8_t age;
    //nx_uint8_t seqNum;
}Neighbor;

#endif