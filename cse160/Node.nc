/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

/*CSE160 Alberc Ej Salcedo & Andy Alvarenga
Recieved Help from Hoa Ngyuen for conceptaual understanding
Documentation help from https://www.cse.wustl.edu/~lu/cse521s/Slides/tutorial
*/

#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/socket.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;
   
   //flooding interface
   uses interface SimpleSend as sendFlood;
   uses interface Receive as externalFloodReceiver;

   //Neighbor discovery interface
   uses interface NeighborDiscovery;
   uses interface RoutingTable;

   //Project3
   uses interface SimpleSend as sending;
   uses interface Receive as forwardReceive;
   uses interface Transport;

   uses interface CommandHandler;
   
}

implementation{
   pack sendPackage;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();
      call NeighborDiscovery.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
      
      // call NeighborDiscovery.startPrint();
   }

   event void AMControl.startDone(error_t err){
      call RoutingTable.start();
      // call NeighborDiscovery.start();
      // call NeighborDiscovery.startPrint();
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* externalFloodReceiver.receive(message_t* msg, void* payload, uint8_t len){
		return msg;
	}

   event message_t* forwardReceive.receive(message_t* msg, void* payload, uint8_t len){
		return msg;
	}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call sendFlood.send(sendPackage, destination);
   }

   event void CommandHandler.printNeighbors(){
      dbg(GENERAL_CHANNEL, "Printing Neighbors\n");
      call NeighborDiscovery.printNodeCache();
      //call NeighborDiscovery.testPrint();
   }

   event void CommandHandler.printRouteTable(){
      //printf("RT PING ....\n");
      call RoutingTable.print();
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){
      dbg(GENERAL_CHANNEL, "Set Server\n");
      call Transport.setServer();
   }

   event void CommandHandler.setTestClient(){
      dbg(GENERAL_CHANNEL, "Set Client\n");
      call Transport.setClient();
   }

   event void CommandHandler.closeClientConnection(){
      dbg(GENERAL_CHANNEL, "Close Client Connection\n");
      call Transport.close();
   }
   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
