#define AM_FORWARDING 25

configuration ForwardC{

    provides interface Receive as receiver;
    provides interface SimpleSend;

}

implementation{    
    components ForwardP;
    receiver = ForwardP.receiver;
    SimpleSend = ForwardP.sending;

    components new SimpleSendC(AM_FORWARDING);
    components new AMReceiverC(AM_FORWARDING);
    ForwardP.internalSend -> SimpleSendC;
    ForwardP.internalReceive -> AMReceiverC;

    components RoutingTableC;
    ForwardP.RoutingTable -> RoutingTableC.RoutingTable;

    components TransportC;
    ForwardP.Transport->TransportC.Transport;
}