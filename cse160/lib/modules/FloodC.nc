/*
Project 1
Group members: Alberc Ej Salcedo & Andy Alvarenga

Other Notes:
TinyOS tutorial, good explinations to primitive functions in tinyOS
https://www.cse.wustl.edu/~lu/cse521s/Slides/tutorial
*/
#include "../../includes/am_types.h"

configuration FloodC {
    
    //floodSender is a component of Flooding that is defined by SimpleSend
    provides interface SimpleSend as sendFlood;
    provides interface Receive as externalFloodReceiver;
    //provides interface SimpleSend as sendNeighbor;
}

implementation {

    components FloodP;
    sendFlood = FloodP.sendFlood;
    externalFloodReceiver = FloodP.externalFloodReceiver;

    //Sets the sender and reciever to the flood channel
    components new SimpleSendC(AM_FLOODING); 
    components new AMReceiverC(AM_FLOODING) as GeneralReceive;

    //FloodP.sendFlood -> SimpleSendC;
    FloodP.receiveFlood -> GeneralReceive;
    FloodP.sending -> SimpleSendC;

    //This allows the code to include the ListC file
    components new ListC(pack, 50) as cacheList;
    FloodP.cache -> cacheList;

    components NeighborDiscoveryC;
    FloodP.NeighborDiscovery -> NeighborDiscoveryC;

}