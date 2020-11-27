/*
Project 1 NOTES
Group members: Alberc Ej Salcedo & Andy Alvarenga

Other Notes:
TinyOS tutorial, good explinations to primitive functions in tinyOS
https://www.cse.wustl.edu/~lu/cse521s/Slides/tutorial
*/

#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/command.h"
#include "../../includes/CommandMsg.h"

module FloodP {
    
    //provides interface SimpleSend as floodSender;
    //Allows us to use the module SimpleSend as an interface named sendFlood
    provides interface SimpleSend as sendFlood;
    provides interface Receive as externalFloodReceiver;
    //provides interface SimpleSend as sendNeighbor;

    //uses interface SimpleSend as sendFlood;
    uses interface SimpleSend as sending;
    uses interface Receive as receiveFlood;
    uses interface List<pack> as cache;
    uses interface NeighborDiscovery;

}

implementation {

    uint16_t seqNum = 0;
    pack sendPackage;

    //prototype
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    bool CheckCache(pack *msg);
    void NodeCache(pack *msg);

    command error_t sendFlood.send(pack msg, uint16_t dest){   

        //TOS_NODE_ID always refers to the node’s own address    
        msg.src = TOS_NODE_ID;
        msg.TTL = MAX_TTL;                   //MAX_TTL == 15 in packet.h
        //msg.protocol = PROTOCOL_PING;    
        msg.seq = seqNum++;
        dbg(FLOODING_CHANNEL, "Flooding Network: %s from sourceNode: %d\n", msg.payload, msg.src);
        call sending.send(msg, AM_BROADCAST_ADDR);
    }

    event message_t* receiveFlood.receive(message_t* msg, void* payload, uint8_t len){
    

        //dbg(FLOODING_CHANNEL, "Packet Received:  %d\n", seqNum);  //TODO print out DATA, METADATA, HEADER 
      
        //error checking: if the length doesn't match the packet size, then there is an error
        if(len==sizeof(pack)){
            
            //creates msg with that packet's payload
            pack* myMsg = (pack*) payload;

            //drops package when TTL dies out
            if(myMsg->TTL == 0){
                return msg;    
            }
            
            //Check the cache for a duplicate and if true drops
            if(CheckCache(myMsg)){
                return msg;
            }
            
            NodeCache(myMsg);
            //Flooding
            if(myMsg->dest == TOS_NODE_ID){

                //We have reached the destination of the packet
                if(myMsg->protocol == PROTOCOL_PING){
                    uint16_t msgSource = myMsg->src;
                    dbg(FLOODING_CHANNEL, "Packet has arrived. %d -> %d\n ", myMsg->src, myMsg->dest);
                    //flips package for acknowledgement
                    myMsg->src = myMsg->dest;
                    myMsg->dest = msgSource;
                    myMsg->protocol = PROTOCOL_PINGREPLY;
                    dbg(FLOODING_CHANNEL, "Acknowledgment sent: %d -> %d\n ", myMsg->src, myMsg->dest);
                    call sendFlood.send(*myMsg, myMsg->dest);
                    return signal externalFloodReceiver.receive(msg, payload, len);
                }

                else {
                    dbg(FLOODING_CHANNEL, "Acknowledgment received from: %d\n ", myMsg->src);
                }
            }    
            //Hasn't reached the dest, so continue Flooding
            else {
                uint16_t temp = myMsg->TTL;
                temp--;
                myMsg->TTL = temp;

                if(myMsg->TTL < 1) {
                    dbg(FLOODING_CHANNEL, "Packet %d DEAD\n", myMsg->seq);
                    return msg;
                }

                //Internal senders allow us to continue flooding packets without changing its contents
                call sending.send(*myMsg, AM_BROADCAST_ADDR);     
            }

            //dbg(FLOODING_CHANNEL, "Node %d dropped packet %d\n", TOS_NODE_ID, myMsg->seq);
            return msg;
        }

        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
    }

    //Checks the cache to see if we have recieved this packet previously
    bool CheckCache(pack *msg) {
        //dbg(FLOODING_CHANNEL, "Entered ChechCache:  %s\n");

        uint16_t cacheSize = call cache.size();
        pack checkMsg;

        uint16_t i = 0;
        for(i = 0; i < cacheSize; i++) {
            checkMsg = call cache.get(i);
            /*
            constructor for pack is in includes/packet.h
            CONCEPT:
                        --checkMsg--            --msg[myMsg]--
                            dest          =?      dest
                            src           =?      src
                            seq		      =?      seq
                            TTL		      =?      TTL
                            protocol      =?      protocol
            */
            if(checkMsg.dest == msg->dest && checkMsg.src == msg->src && checkMsg.seq == msg->seq){
               return TRUE;
            }
        }

        return FALSE;
    }

    //Caching the packets uint16t_t size = call cache.size();
    void NodeCache(pack *msg) {
        //dbg(GENERAL_CHANNEL, "Now Storing msg into cache... \n");
        //dbg(FLOODING_CHANNEL, "Entered NodeCache  \n");
        
        //we need delete old information
        if (call cache.isFull()) {
            //dbg(FLOODING_CHANNEL, "Popping Cache  \n");
            call cache.popback();
        }

        //dbg(FLOODING_CHANNEL, "Saved to cache  \n");
        //inserts the packet into the cache 
        call cache.pushfront(*msg);
    }


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