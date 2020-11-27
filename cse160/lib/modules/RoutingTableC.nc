#include "../../includes/neighbor.h"
#include "../../includes/mapping.h"
#define AM_ROUTING 20

configuration RoutingTableC {

    provides interface RoutingTable;

}

implementation {    
    components RoutingTableP;
    RoutingTable = RoutingTableP.RoutingTable;

    components NeighborDiscoveryC;
    RoutingTableP.NeighborDiscovery -> NeighborDiscoveryC;

    components new SimpleSendC(AM_ROUTING);
    RoutingTableP.routeSender -> SimpleSendC;

    components new AMReceiverC(AM_ROUTING);
    RoutingTableP.receiveRoute -> AMReceiverC;

    components new TimerMilliC() as timer;
    RoutingTableP.timer -> timer;

    components RandomC as random;
    RoutingTableP.random -> random;

}