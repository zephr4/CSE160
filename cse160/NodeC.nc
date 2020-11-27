/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}

implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    //components new ListC(pack, 50) as neighborCache; 

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    //This wires the FloodP module s.t. each node may use the included functions
    components FloodC;
    Node.sendFlood -> FloodC.sendFlood;                                     //From Renee's Document
    Node.externalFloodReceiver -> FloodC.externalFloodReceiver;

    components NeighborDiscoveryC;
    Node.NeighborDiscovery -> NeighborDiscoveryC;
    //NeighborDiscoveryC.neighborCache -> neighborCache;

    components RoutingTableC;
    Node.RoutingTable -> RoutingTableC;

    components ForwardC;
    Node.sending -> ForwardC.SimpleSend;
    Node.forwardReceive -> ForwardC.receiver;

    components TransportC;
    Node.Transport -> TransportC;
}
