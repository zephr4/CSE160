#define AM_TRANSPORT 30

configuration TransportC {

    provides interface Transport;
}

implementation {

    components TransportP;
    Transport = TransportP.Transport;

    components new ListC(socket_store_t, 100) as socketCache;
    TransportP.socketCache -> socketCache;

    components new QueueC(pack, 100) as pktQueue;
    TransportP.pktQueue -> pktQueue;

    components new SimpleSendC(AM_TRANSPORT) as send;
    TransportP.send -> send;

    components ForwardC;
	TransportP.send -> ForwardC.SimpleSend;

    components new AMReceiverC(AM_TRANSPORT);

    components new TimerMilliC() as timer;
    TransportP.timer -> timer;

}