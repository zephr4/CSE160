#include "../../includes/neighbor.h"
#define AM_NEIGHBOR 15

configuration NeighborDiscoveryC {

    provides interface NeighborDiscovery;
    //uses interface List<pack> as neighborCache;
}

implementation {

    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    components new TimerMilliC() as timer;
    NeighborDiscoveryP.timer -> timer;

    components new TimerMilliC() as print;
    NeighborDiscoveryP.print -> print;

    components RandomC as random;
    NeighborDiscoveryP.random -> random;

    components new ListC(Neighbor, 100) as dirtyCache;
    NeighborDiscoveryP.dirtyCache -> dirtyCache;

    components new SimpleSendC(AM_NEIGHBOR);
    NeighborDiscoveryP.sendNeighbor -> SimpleSendC;

    components new AMReceiverC(AM_NEIGHBOR);
    NeighborDiscoveryP.neighborReceiver -> AMReceiverC;

    // components new ListC(Neighbor, 100) as neighborCache;
    // NeighborDiscoveryP.neighborCache -> neighborCache;
    
    // components FloodC;
    // NeighborDiscoveryP.sendNeighbor -> FloodC.sendNeighbor;
}