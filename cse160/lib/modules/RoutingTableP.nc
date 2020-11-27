#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/neighbor.h"
#include "../../includes/mapping.h"
#include "../../includes/protocol.h"

module RoutingTableP {
    
    provides interface RoutingTable;

    uses interface SimpleSend as routeSender;
    uses interface Receive as receiveRoute;
    uses interface NeighborDiscovery;
    uses interface Timer<TMilli> as timer;
    uses interface Random as random;
}

implementation {
    
    pack sendpackage;
    uint16_t RTsize;
    uint16_t NCsize;

    //create an array of type Neighbor/mapping, with the size of the cache for each node
    Neighbor* temp;
    Neighbor cacheClone[100];
    mapping routingTable[100];
    uint32_t track = 0;

    void createRT();
    void sendRT();
    uint16_t search(uint16_t nAddr);
    void initialize(uint16_t dest, uint16_t nextHop, uint16_t cost);
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

    command void RoutingTable.start() {
        // RTsize = call NeighborDiscovery.neighborCacheSize();
        uint16_t period = 10000;
        //dbg(ROUTING_CHANNEL, "Begin Routing...");
        call NeighborDiscovery.start();
        call timer.startPeriodic(period);
    }

    event void timer.fired() {
        createRT();
        sendRT();
    }

    void createRT() {
        
        uint16_t i;
        uint16_t j;
        //uint16_t cacheCloneSize = 0;
        //cacheCloneSize = call NeighborDiscovery.neighborCacheSize();
        //cacheClone = call NeighborDiscovery.retrieveNeighborCache();
        
        temp = call NeighborDiscovery.retrieveNeighborCache();
        NCsize = call NeighborDiscovery.neighborCacheSize();
        memcpy(cacheClone, temp, 100);

        //dbg(ROUTING_CHANNEL, "Initialize RT neighbors... \n");
        //set the Neighbors nodes for each TOS_NODE_ID to be cost = 1 
        for(i = 0; i < NCsize; i++) {
            if(search(cacheClone[i].neighborAddr)) {
                initialize(cacheClone[i].neighborAddr, cacheClone[i].neighborAddr, 1);
            }
        }

        //Now that we set dest and nextHop for each, reset cost
        for(i = 0; i < RTsize; i++) {
            if(routingTable[i].cost == 1) {
                routingTable[i].cost = 1000;
            }
        }

        //Now find each neighbor and set the cost = 1 and nextHop = nAddr
        for(i = 0; i < RTsize; i++) {
            for(j = 0; j < NCsize; j++) {
                if(routingTable[i].dest == cacheClone[j].neighborAddr) {
                    routingTable[i].cost = 1;
                    routingTable[i].nextHop = cacheClone[j].neighborAddr; 
                }
            }
        }

        //dbg(ROUTING_CHANNEL, "RT initialization DONE. \n"); 
    }

    command uint16_t RoutingTable.retrieveNextHop(uint16_t dest){
        uint32_t i;
        for(i = 0; i < 100; i++){
            if(routingTable[i].dest == dest && routingTable[i].cost < 1000){
                return routingTable[i].nextHop;
            }
        }
    }

    void sendRT() {

        uint16_t i;

        //we are only sending 
        mapping sRT[1];
        
        //dbg(ROUTING_CHANNEL, "Start sending RT packets... \n");
        for(i = 0; i < RTsize; i++) {
            //if cost == 1000(infinity), then we don't have a path
            if(routingTable[i].cost == 1000) {
                routingTable[i].cost == 1000;
                routingTable[1].nextHop == 1000;
                dbg(ROUTING_CHANNEL, "No routing path to node %d\n", i);
            }

            //we are only sending the RT info of known neighbors (i.e. dest = nextHop , cost : 2 = 2 , 1)
            else if(routingTable[i].dest == routingTable[i].nextHop && routingTable[i].nextHop != 1000 && routingTable[i].cost == 1){
                sRT[0].dest = routingTable[i].dest;
                sRT[0].nextHop = routingTable[i].nextHop;
                sRT[0].cost = routingTable[i].cost;
                
                //we are sending the payload as -> (uint8_t*)sendRT because we need to embody the entire  
                makePack(&sendpackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_PING, 0, (uint8_t*)sRT, sizeof(mapping));
                //dbg(ROUTING_CHANNEL, "Send RT Pack with -> source: %d, dest: %d , nextHop: %d , cost: %d\n", TOS_NODE_ID, sRT[0].dest, sRT[0].nextHop, sRT[0].cost);
                call routeSender.send(sendpackage, AM_BROADCAST_ADDR);
            }
        }
    }

    event message_t* receiveRoute.receive(message_t* msg, void* payload, uint8_t len) {
        
        uint16_t i;

        mapping receivedRT[1];

        pack* myMsg = (pack*) payload;
        
        //copies dest, nextHop, and cost from the payload to received RT
        memcpy(receivedRT, myMsg->payload, sizeof(mapping));
        //dbg(ROUTING_CHANNEL, "Received RT Pack with -> source: %d, dest: %d , nextHop: %d , cost: %d\n", TOS_NODE_ID, receivedRT[0].dest, receivedRT[0].nextHop, receivedRT[0].cost); 

        //dbg(ROUTING_CHANNEL, "Begin Updating the RT... \n");
        i = search(receivedRT[0].dest);
        if(i != 1000) {
            //update the RT table if we can find an index in the RT in which it has nextHop = received src
            //this means we will update cost of the path for non-directly connected neighbors by (received cost + 1)
            //If receivedRT[0].nextHop = TOS_NODE_ID (meaning the two nodes are neighbors), then don't update
            if((routingTable[i].nextHop = myMsg->src) && (receivedRT[0].cost < 1000) && (receivedRT[0].nextHop != TOS_NODE_ID)) {
                routingTable[i].cost = receivedRT[0].cost + 1;
            }

            //We have another case when the current cost in RT is greater than the (received cost + 1)
            else if(routingTable[i].cost > receivedRT[0].cost + 1) {
                routingTable[i].nextHop = myMsg->src;
                routingTable[i].cost = receivedRT[0].cost + 1;
            }
        }

        //If we are seeing a new node, just add it to the RT
        else {
            //dbg(ROUTING_CHANNEL, "Initialize a new neighbor node \n");
            initialize(receivedRT[0].dest, myMsg->src, receivedRT[0].cost);
        }

        return msg;
    }

    // void cloneCache() {

    //     uint16_t i = 0;
    //     //dbg(ROUTING_CHANNEL, "Cloning Neighbor Cache... \n");
    //     cacheClone = call NeighborDiscovery.retrieveNeighborCache();
    // }

    uint16_t search(uint16_t nAddr) {
        uint16_t i;
        for(i = 0; i < RTsize; i++) {
            if(routingTable[i].dest == nAddr) {
                return i;

                /*
                    If routingTable[i].dest == nAddr
                    then return the index of the routing table
                    this will give us the position of neighbors
                */
            }
        }

        //1000 == our inifinity
        return 1000;

        /*
            On initialization we will continually return 1000.
            This is because there is no info in our RT.
            Therefore by doing this we can fill in our dest, nextHop, and 
                initially cost is set to an "arbitrary" value
            This will later allow us to truly find neighbors and set the true cost
        */
    }

    void initialize(uint16_t dest, uint16_t nextHop, uint16_t cost) {

        if(dest == TOS_NODE_ID || RTsize >= call NeighborDiscovery.neighborCacheSize()) {
            //Do nothing because we have reached the size limit of the RT array
            //  or if the dest == TOS_NODE_ID then we don't have to update because the cost is always 0 to  itself
        }

        else {
            routingTable[RTsize].dest = dest;
            routingTable[RTsize].nextHop = nextHop;
            routingTable[RTsize].cost = 1;
            RTsize++;
            //dbg(ROUTING_CHANNEL,"RT Size: %d\n", RTsize);
        }

    }
    
    command void RoutingTable.print(){
        uint16_t i;
        //printf("Entered RT Print.......\n");
        //dbg(ROUTING_CHANNEL, "----------Routing Table----------\n");
        for(i = 0; i < RTsize; i++){
            dbg(ROUTING_CHANNEL, "Dest[%d]  |  nextHop[%d]   |   Cost[%d]\n", routingTable[i].dest, routingTable[i].nextHop, routingTable[i].cost);
        }
        //dbg(ROUTING_CHANNEL, "----------Routing Table----------\n");
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) {
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
    }

}