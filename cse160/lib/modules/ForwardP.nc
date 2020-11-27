#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/TCP.h"
#include "../../includes/protocol.h"

module ForwardP{
    provides interface SimpleSend as sending;
    provides interface Receive as receiver;

    uses interface SimpleSend as internalSend;
    uses interface Receive as internalReceive;
    uses interface RoutingTable;
    uses interface Transport;
}

implementation{
    //internal sender
    command error_t sending.send(pack myMsg, uint16_t dest){
        uint16_t nextHop = call RoutingTable.retrieveNextHop(dest);
        if(nextHop < 1 || nextHop == 1000){
            dbg(ROUTING_CHANNEL, "Route not found: nextHop[%u]\n", nextHop);
        }
        // if(nextHop == 1000){
        //     dbg(ROUTING_CHANNEL, "Route not found: nextHop[%u]\n", nextHop);
        // }
        else{
            dbg(ROUTING_CHANNEL, "Packet forward: %u, destination: %u\n", nextHop, dest);
            call internalSend.send(myMsg, nextHop);
        }
    }

    //internal reciever
    event message_t* internalReceive.receive(message_t* msg, void* payload, uint8_t len){
        uint16_t capture; //captures source and inserts it into myMsg->dest
        uint16_t nextHop;
        uint16_t TTL;

        pack* myMsg = (pack*) payload;
        tcpP* tcpPack = (tcpP*)myMsg->payload;
        myMsg->TTL = myMsg->TTL - 1;

        if(myMsg->dest == TOS_NODE_ID){
            if(myMsg->protocol == PROTOCOL_PINGREPLY){
                dbg(ROUTING_CHANNEL, "Recieved Ping Reply\n");
            }
            else if(myMsg->protocol == PROTOCOL_PING){
                dbg(ROUTING_CHANNEL, "Pinging\n");
                capture = myMsg->src;
                TTL = 20; //TODO test other TTL values
                
                myMsg->TTL = TTL;
                myMsg->src = myMsg->dest;
                myMsg->dest = capture;
                call sending.send(*myMsg, myMsg->dest);
            }
            else if(myMsg->protocol == PROTOCOL_TCP){
                dbg(ROUTING_CHANNEL, "Sending SYN from:%u with flag:%u\n", TOS_NODE_ID, tcpPack->flags);
                call Transport.receive(myMsg);
            }
        }
        else{
            nextHop = call RoutingTable.retrieveNextHop(myMsg->dest);
            if(nextHop < 1){
                dbg(ROUTING_CHANNEL, "Packet Dropped: nextHop%u\n", nextHop);
                return msg;
            }
            if(nextHop >= 1000){
                dbg(ROUTING_CHANNEL, "Packet Dropped: nextHop%u\n", nextHop);
                return msg;
            }
            if(myMsg->TTL == 0){
                dbg(ROUTING_CHANNEL, "Packet Dropped: TTL expired - %u\n", TTL);
            }
            call sending.send(*myMsg, nextHop);
        }
        return msg;
    }
}