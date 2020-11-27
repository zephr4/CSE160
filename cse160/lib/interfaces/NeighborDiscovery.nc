#include "../../includes/neighbor.h"

interface NeighborDiscovery {

    command void start();
    command void neighborRecieve(uint16_t nodeSrc);
    command void printNodeCache();
    command void startPrint();
    command Neighbor* retrieveNeighborCache();
    command uint16_t neighborCacheSize();
}