#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/neighbor.h"

module NeighborDiscoveryP {
    
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as print; 

    uses interface Timer<TMilli> as timer;                  //neighbor discorvery internal timer
    uses interface Random as random;                        //used to create a random timer
    // uses interface List<Neighbor> as neighborCache; 
    uses interface List<Neighbor> as dirtyCache;    
    //uses interface SimpleSend as neighborSender;
    uses interface SimpleSend as sendNeighbor;
    uses interface Receive as neighborReceiver;
}

implementation {

    pack sendPackage;
    Neighbor neighborCache[100];
    uint16_t globalIndex = 0;

    uint16_t s2;
    uint8_t sequence;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    bool findNeighbor(pack *msg);
    void update();

    command void NeighborDiscovery.start(){
        uint32_t Tstart;

        Tstart = 5000;
        call timer.startPeriodic(Tstart);
    }

    /*Create a new timer that finshes after flooding has gone on for a sufficient ammount of time[huge time]. when it finishes fire to orint neighbor*/
    command void NeighborDiscovery.startPrint(){
        uint32_t Tstart; //use 32 bits not 16
        int initial = 100000; //TODO change this to mess with timer
        
        Tstart = initial;
        call print.startOneShot(Tstart);
    }   

    command void NeighborDiscovery.neighborRecieve(uint16_t nodeSrc){
        uint16_t i = 0;
        for(i = 0; i < 100; i++){
            if(neighborCache[i].neighborAddr == nodeSrc){
                neighborCache[i].age = 4;
                return;
            }
        }
            neighborCache[globalIndex].neighborAddr = nodeSrc;
            neighborCache[globalIndex].age = 4;
            globalIndex++;
            return;

    }

    // command void NeighborDiscovery.neighborRecieve(pack *msg){
    //     if(findNeighbor(msg)){ 
    //         //dbg(NEIGHBOR_CHANNEL, "Node %d already in the neighbor cache\n", TOS_NODE_ID);
    //     }
    //     else{
    //         Neighbor found;
    //         found.neighborAddr = msg->src;
    //         found.NDsrc = msg->dest;
    //         found.age = 0;
    //         //found.seqNum = msg->seq;
    //         call neighborCache.pushback(found); //adds to neighborCache, creating network map
    //         s2 = call neighborCache.size();
    //     }
    // }



	command void NeighborDiscovery.printNodeCache(){
		uint32_t i = 0;
		for(i = 0; i < 100; i++){
			if(neighborCache[i].neighborAddr != 0){
				dbg(NEIGHBOR_CHANNEL, "Neighbor: %u \n", neighborCache[i].neighborAddr);
                //dbg(NEIGHBOR_CHANNEL, "Age: %u \n", neighborCache[i].age);
			}
		}
	}

    // command void NeighborDiscovery.printNodeCache(){
    //     uint32_t i = 0;
    //     uint32_t j = 0;
    //     uint16_t size = call neighborCache.size();
    //     dbg(NEIGHBOR_CHANNEL, "Neighbopr size: %u\n", size);

    //     for(i = 0; i < size; i++){
    //         Neighbor tempNode = call neighborCache.get(i);
    //         if(call dirtyCache.size() == 0){
    //             Neighbor dirty = tempNode;
    //             call dirtyCache.pushback(dirty);
    //         }
    //         else{
    //             for(j = 0; j < call dirtyCache.size(); j++){
    //                 Neighbor dirty = call dirtyCache.get(j);
    //                 if(dirty.neighborAddr == tempNode.neighborAddr){
    //                     call neighborCache.pop(i);
    //                 }
    //                 else{
    //                     call dirtyCache.pushback(dirty);
    //                 }
    //             }
    //         }
    //     }

        // for(i = 0; ; i++){
        //     Neighbor node = call dirtyCache.get(i);
        //     dbg(NEIGHBOR_CHANNEL, "%u\n", node.neighborAddr);
        // }
        
    //}

    // command void NeighborDiscovery.printNodeCache(){
    //     //uint16_t condition = call neighborCache.size(); //we are going to use the size of the list
    //     if (call neighborCache.size() > 0){ //if the size of the list is greater than 0, we still need to run through
    //         uint16_t size = call neighborCache.size(); //size of our "neighorhood"
    //         //uint16_t currentNode = TOS_NODE_ID;
    //         uint16_t i = 0;
    //         //pack node;
 
    //         //dbg(NEIGHBOR_CHANNEL, "Cache size: %d\n", size);
    //         for(i = 0; i < size; i++){
    //             Neighbor node = call neighborCache.get(i);
    //             uint16_t currentNode = TOS_NODE_ID;
    //             dbg(NEIGHBOR_CHANNEL, "\n", node.neighborAddr);
    //             //dbg(NEIGHBOR_CHANNEL, "Node[%d] is the neighbor of currentNode[%d]\n", node.neighborAddr, currentNode);
    //         }
    //     }
    //     else{
    //         dbg(NEIGHBOR_CHANNEL, "No neighbors for currentNode[%d]\n", TOS_NODE_ID);   //TOS_NODE_ID is the currentNode
    //     }
    // }

    event void timer.fired(){
        char* neighborPayload;
        neighborPayload = "Neighbor Packet";
        
        //dbg(NEIGHBOR_CHANNEL, "Begin Neighbor Discovery ...\n");
        /* How to catch neighbor Dupes:
                1. Keep track of the seq number. When a ND packet is created we assign it a unique value (sequence++)
                2. When ND packet arrives at a neighbor store that packets seq number 
                3. Whenever a packet arrives first check the seq number, if we see the sequence number in our cache, then don't add
                    -this is better than what we did before, because now instead checking if the node is seen we check if the flood 
                        packet has been seen. We do this because of the nature flooding were a packet converges only when it has taken
                        each path. This idea shows that the same packet can arrive more than once at the same node. */
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_PING, 0, (uint8_t*) neighborPayload, PACKET_MAX_PAYLOAD_SIZE);
        //dbg(FLOODING_CHANNEL, "Neighbor Discovery for source node: %d\n", sendPackage.src);
        call sendNeighbor.send(sendPackage, AM_BROADCAST_ADDR);
        update();

    }
    
    event message_t* neighborReceiver.receive(message_t* msg, void* payload, uint8_t len) {
        pack* myMsg = (pack *) payload;

        if (myMsg->dest == AM_BROADCAST_ADDR) {
            myMsg->dest = myMsg->src;
            myMsg->src = TOS_NODE_ID;
            myMsg->protocol = PROTOCOL_PINGREPLY;
            call sendNeighbor.send(*myMsg, myMsg->dest);
        }
        else if (myMsg->dest == TOS_NODE_ID){
            //call NeighborDiscovery.neighborRecieve(myMsg);
            call NeighborDiscovery.neighborRecieve(myMsg->src);
        }

        return msg;
    }

    event void print.fired(){
        call NeighborDiscovery.printNodeCache();
    }

    command Neighbor* NeighborDiscovery.retrieveNeighborCache(){
        // Neighbor temp = call neighborCache.get(i);
        // return temp;
        return neighborCache;
    }

    command uint16_t NeighborDiscovery.neighborCacheSize(){
        return globalIndex;
    }

    // bool findNeighbor(pack *msg){
    //     Neighbor checkNeighbor;
    //     uint16_t size = call neighborCache.size();
    //     uint16_t i = 0;

    //     //dbg(NEIGHBOR_CHANNEL, "Node %d entering findNeighbor\n", TOS_NODE_ID);

    //     for(i = 0; i < size; i++){
    //         //we are capturing nodbg(NEIGHBOR_CHANNEL, "Neighbor [%u]\n", node.neighborAddr);e in our neighborCache
    //         checkNeighbor = call neighborCache.get(i);

    //         // dbg(NEIGHBOR_CHANNEL, "msg's src: %d\n", msg->src);
    //         // dbg(NEIGHBOR_CHANNEL, "checkNeighbor's addr: %d\n", checkNeighbor.neighborAddr);
    //         // dbg(NEIGHBOR_CHANNEL, "checkNeighbor seen?: %d\n", checkNeighbor.seen);
            
    //         if(msg->src == checkNeighbor.neighborAddr) { //&& msg->seq == checkNeighbor.seqNum)
    //             //This means msg is already labeled as a neighbor
                
    //             //dbg(NEIGHBOR_CHANNEL, "Node[%d] is your neighbor\n", checkNeighbor.neighborAddr);
    //             return TRUE;
    //         }
    //         else{
    //             //dbg(NEIGHBOR_CHANNEL, "I am Node[%d], I am not your Neighbor\n", checkNeighbor.neighborAddr);
    //             return FALSE;
    //         }
    //     }
    // }

    void update() {
        uint16_t i = 0;
        uint16_t j = 0;

        for(i = 0; i < 100; i++){
            if(neighborCache[i].age > 1){
                neighborCache[i].age - 1;
            }
        }

        for(i = 0; i < 100; i++){
            if(neighborCache[i].age == 1){
                for(j = i; j < 99; j++){
                    neighborCache[j].neighborAddr = neighborCache[j++].neighborAddr = 0;
                    neighborCache[j].age = neighborCache[j++].age = 0;
                }
                neighborCache[99].neighborAddr = 0;
                neighborCache[99].age = 0;
                globalIndex--;
            }
        }
    }

    // void update() {
    //     Neighbor neighbor;
    //     uint16_t size = call neighborCache.size();
    //     uint16_t i = 0;
        
    //     if(call neighborCache.isEmpty() == FALSE) {
    //         for(i = 0; i < size; i++) { 
    //             neighbor = call neighborCache.get(i);
    //             neighbor.age = neighbor.age + 1;

    //             //If the age of the neighbor is greater than 4, then remove the link
    //             if(neighbor.age > 4) {
    //                 call neighborCache.pop(i);
    //                 i--;
    //             }
    //         }
    //     }
    // }

    //makePack code logic
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) {
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
    }
}

//Test
// command void NeighborDiscovery.printNodeCache(){
//         uint32_t i = 0;
//         uint32_t j = 0;
//         uint16_t size = call neighborCache.size();
        
//         //The first tuple is NULL
//         Neighbor tempNode;
//         tempNode.neighborAddr = -1;
//         tempNode.age = -1;
//         dirtyCache.pushback(tempNode);

//         for(i = 0; i < size; i++){
//             Neighbor node = call neighborCache.get(i);
//             if(node.neighborAddr != 0){
//                 for(j = 0; j < call dirtyCache.size(); j++){
//                     Neighbor dirty = dirtyCache.get(j);
//                     if(dirty.neighborAddr == node.neighborAddr){         //at first iteration: is -1 == neighborAddr
//                         neighborCache.pop(i);
//                     }
//                     else {
//                         dirtyCache.pushback(dirty);
//                     }
//                 }             
//                 dbg(NEIGHBOR_CHANNEL, "Neighbor [%u]\n", node.neighborAddr);
//             }
//         }
        
//     }