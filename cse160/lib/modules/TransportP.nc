#include "../../includes/packet.h"
#include "../../includes/socket.h"

//TODO RENAME to match naming convention in PDF
module TransportP {
   provides interface Transport;

   uses interface List<socket_store_t> as socketCache;
   uses interface Queue<pack> as pktQueue;
   uses interface SimpleSend as send;
   uses interface Timer<TMilli> as timer;
   //uses interface RoutingTable;
}

implementation {

   void connectDone(socket_store_t fd);
   socket_store_t getSocket(uint8_t dest, uint8_t src);
   socket_store_t serverSocket(uint8_t dest);

   //returns client sokcet
   socket_store_t getSocket(uint8_t dest, uint8_t src){
      socket_store_t socket;
      uint16_t i = 0;
      uint16_t size = 0;
      size = call socketCache.size();
      for(i = 0; i < size; i++){
         socket = call socketCache.get(i);
         if(socket.dest.port == src && socket.src.port == dest){
            return socket;
         }
      }
   }

   socket_store_t serverSocket(uint8_t dest){
      socket_store_t socket;
      uint16_t i = 0;
      uint16_t size = call socketCache.size();

      for(i = 0; i < size; i++){
         socket = call socketCache.get(i);
         if(socket.state == LISTEN && socket.src.port == dest){
            return socket;
         }         
      }
      dbg(TRANSPORT_CHANNEL, "Socket not found\n");
   }
   
   event void timer.fired(){
      pack myMsg = call pktQueue.head();
      tcpP* tcpPack = (tcpP*)myMsg.payload;
      pack sendMsg;
      socket_store_t socket = getSocket(tcpPack->srcPort, tcpPack->destPort);

     if(socket.dest.port){
         //Look at: do we need to push this back? is it a dupe? 
         call socketCache.pushback(socket);
         call Transport.makePack(&sendMsg, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, payloadSize);
         call send.send(sendMsg, socket.dest.addr);
      }
   }

   // command socket_t socket();

   // command error_t bind(socket_t fd, socket_addr_t *addr);

   // command socket_t accept(socket_t fd);

   // command uint16_t write(socket_t fd, uint8_t *buff, uint16_t bufflen);

   command error_t Transport.receive(pack* msg) {
      
      socket_store_t socket;
      tcpP* myMsg;
      pack sendPack;
      tcpP* tcpPack;
      uint16_t i = 0;
      uint16_t j = 0;
      myMsg = (tcpP*)msg->payload;

      //dbg(ROUTING_CHANNEL, "MSG RECIEVED\n");
      //We can use this for efficiency 
      if(myMsg->flags == SYN || myMsg->flags == SYN_ACK || myMsg->flags == ACK){

         if(myMsg->flags == SYN){
            dbg(TRANSPORT_CHANNEL, "Recieved SYN\n");
            socket = serverSocket(myMsg->destPort);

            if(socket.state == LISTEN) {
               //If the server that we are trying to connect to is listening and it receives a SYN packet, then we change the state
               //    add an update socket to the cache, and send a SYN_ACK packet
               socket.state = SYN_RCVD;
               socket.dest.port = myMsg->srcPort;
               socket.dest.addr = msg->src;
               call socketCache.pushback(socket);
               
               tcpPack = (tcpP*)(sendPack.payload);
               tcpPack->destPort = socket.dest.port;
               tcpPack->srcPort = socket.src.port;
               tcpPack->seq = 1;
               tcpPack->ack = myMsg->seq + 1;
               tcpPack->flags = SYN_ACK;
               call Transport.makePack(&sendPack, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, PACKET_MAX_PAYLOAD_SIZE);

               call send.send(sendPack, socket.dest.addr);
            } 
         }

         if(myMsg->flags == SYN_ACK){
            //The SYN_ACK was received so edit the socket s.t. state = ESTABLISHED 
            //Send and ACK back to server
            dbg(TRANSPORT_CHANNEL, "Sending SYN_ACK\n");
            socket = getSocket(myMsg->destPort, myMsg->srcPort);
            socket.state = ESTABLISHED;
            call socketCache.pushback(socket);

            tcpPack = (tcpP*)(sendPack.payload);
            tcpPack->destPort = socket.dest.port;
            tcpPack->srcPort = socket.src.port;
            tcpPack->seq = 1;
            tcpPack->ack = myMsg->seq + 1;
            tcpPack->flags = ACK;
            dbg(TRANSPORT_CHANNEL, 'Sending ACK\n');
            call Transport.makePack(&sendPack, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, PACKET_MAX_PAYLOAD_SIZE);

            call send.send(sendPack, socket.dest.addr);
            connectDone(socket);
         }

         if(myMsg->flags == ACK){
            dbg(TRANSPORT_CHANNEL, "Received ACK\n");
            socket = getSocket(myMsg->destPort, myMsg->srcPort);

            //This updates the server socket to state = ESTABLISHED
            if(socket.state == SYN_RCVD) {
               socket.state = ESTABLISHED;
               call socketCache.pushback(socket);
            }
         }
      }
      
      if(myMsg->flags == DATA || myMsg->flags == DATA_ACK){
         if(myMsg->flags == DATA){
            socket = getSocket(myMsg->destPort, myMsg->srcPort);
            if(socket.state == ESTABLISHED){
               tcpPack = (tcpP*)sendPack.payload;
               if(myMsg->payload[0] != 0){
                  i = socket.lastRcvd + 1;
                  j = 0;

                  while(j < myMsg->ack){
                     socket.rcvdBuff[i] = myMsg->payload[j];
                     socket.lastRcvd = myMsg->payload[j];
                     i++;
                     j++;
                  }
               }
               else{
                  i = 0;//reset
                  while(i < myMsg->ack){
                     socket.rcvdBuff[i] = myMsg->payload[i];
                     socket.lastRcvd = myMsg->payload[i];
                     i++;
                  }
               }
               socket.effectiveWindow = SOCKET_BUFFER_SIZE - socket.lastRcvd + 1;
               call socketCache.pushback(socket);
               tcpPack->srcPort = socket.src.port;
               tcpPack->destPort = socket.dest.port;
               tcpPack->seq = myMsg->seq;
               tcpPack->ack = myMsg->seq + 1;  
               tcpPack->prevAck = myMsg->seq + 1;
               tcpPack->window = socket.effectiveWindow;
               tcpPack->flags = DATA_ACK;

               dbg(TRANSPORT_CHANNEL, "Sending DATA_ACK\n");
               call Transport.makePack(&sendPack, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, payloadSize);
               call send.send(sendPack, socket.dest.addr);
            }
         }
         else if (myMsg->flags == DATA_ACK) {
            socket = getSocket(myMsg->destPort, myMsg->srcPort);
            if(socket.state == ESTABLISHED) {
               if(myMsg->window != 0 && myMsg->prevAck != socket.effectiveWindow) {
                  tcpPack = (tcpP*)(sendPack.payload);
                  i = myMsg->prevAck + 1;
                  j = 0;

                  while(j < myMsg->window && j < payloadSize && i <= socket.effectiveWindow) {
                     tcpPack->payload[j] = i;
                     i++;
                     j++;
                  }

                  call socketCache.pushback(socket);

                  tcpPack->destPort = socket.dest.port;
                  tcpPack->srcPort = socket.src.port;
                  tcpPack->seq = myMsg->prevAck;
                  tcpPack->ack = i - 1 - myMsg->prevAck;
                  tcpPack->flags = DATA;
                  call Transport.makePack(&sendPack, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, payloadSize);

                  call pktQueue.dequeue();
                  call pktQueue.enqueue(sendPack);
                  
                  dbg(TRANSPORT_CHANNEL, "Sending New Data \n");
                  call send.send(sendPack, socket.dest.addr);
               }
            }
         
            else{
               socket.state = FIN;
               call socketCache.pushback(socket);
               tcpPack = (tcpP*)sendPack.payload;
               tcpPack->srcPort = socket.src.port;
               tcpPack->destPort = socket.dest.port;
               tcpPack->seq = 1;
               tcpPack->ack = 1;
               tcpPack->flags = FIN;
               call Transport.makePack(&sendPack, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, payloadSize);
               call send.send(sendPack, socket.dest.addr);
            }
         }
      }
   
      if(myMsg->flags == FIN || myMsg->flags == FIN_ACK) {
         //dbg(TRANSPORT_CHANNEL,"Received a FIN_ACK\n");
         if(myMsg->flags == FIN){
            dbg(TRANSPORT_CHANNEL,"Received a FIN\n");
            socket = getSocket(myMsg->destPort, myMsg->srcPort);
            socket.dest.port = myMsg->srcPort;
            socket.dest.addr = msg->src;
            socket.state = CLOSED;

            tcpPack = (tcpP*)sendPack.payload;
            tcpPack->srcPort = socket.src.port;
            tcpPack->destPort = socket.dest.port;
            tcpPack->seq = 1;
            tcpPack->ack = tcpPack->seq + 1;
            tcpPack->flags = FIN_ACK;

            call Transport.makePack(&sendPack, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, payloadSize);
            call send.send(sendPack, socket.dest.addr);
         }
         if(myMsg->flags == FIN_ACK){
            dbg(TRANSPORT_CHANNEL, "Recieved FIN_ACK");
            socket = getSocket(myMsg->destPort, myMsg->srcPort);
            socket.state = CLOSED;
         }
      }
   }

   // command uint16_t read(socket_t fd, uint8_t *buff, uint16_t bufflen);

   command error_t Transport.connect(socket_store_t fd) {
      pack myMsg;
      tcpP* tcpPack;
      socket_store_t socket = fd;

      tcpPack = (tcpP*)(myMsg.payload);
      tcpPack->srcPort = socket.src.port;
      tcpPack->destPort = socket.dest.port;
      tcpPack->flags = 2;
      tcpPack->seq = 1;
      tcpPack->ack = 0;
      
      // A protocol value of 4 == PROTOCOL_TCP
      call Transport.makePack(&myMsg, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, payloadSize);
      socket.state = SYN_SENT;
      dbg(ROUTING_CHANNEL, "Node state: %u\n", socket.state);
      call send.send(myMsg, socket.dest.addr);
   }

   void connectDone(socket_store_t fd){
      pack myMsg;
      tcpP* tcpPack;
      uint16_t i = 0;
      socket_store_t socket = fd;
      uint16_t start = 100000; //TODO change up time

      tcpPack = (tcpP*)(myMsg.payload);
      tcpPack->srcPort = socket.src.port;
      tcpPack->destPort = socket.dest.port;
      tcpPack->flags = 0;
      tcpPack->seq = 0;

      // bool condition = TRUE;
      // for(condition){
      //    if(i <= socket.effectiveWindow && i < payloadSize){
      //       tcpPack->payload[i] = i;
      //       continue;
      //    }
      //    else{
      //       condition = FALSE;
      //       break;
      //    }
      // }

      while(i <= socket.effectiveWindow && i < payloadSize){
         tcpPack->payload[i] = i;
         i++;
      }

      tcpPack->ack = i;
      call Transport.makePack(&myMsg, TOS_NODE_ID, socket.dest.addr, 20, 4, 0, tcpPack, payloadSize);
      dbg(ROUTING_CHANNEL, "Node state: %u", socket.state);
      call pktQueue.enqueue(myMsg);
      call timer.startOneShot(start);
      call send.send(myMsg, socket.dest.addr);
   }

   command error_t Transport.close() {
      
      // Hard coded because we are unsure of how to pass values through the python commands/commandHandler
      uint16_t addr = 2;
      uint16_t srcPort = 17;
      uint16_t dest = 4;
      uint16_t destPort = 19;
      uint8_t i = 0;
      socket_store_t socket;

      for(i = 0; i < call socketCache.size(); i++) {
         socket = call socketCache.get(i);
         //It never reaches the if statement because of faulty routing table
         if(socket.src.addr == addr && socket.src.port == srcPort && socket.dest.addr == dest && socket.dest.port == destPort && socket.state == CLOSED) {
            // remove the socket from the list because it is now closed
            call socketCache.pop(i);
            dbg(TRANSPORT_CHANNEL,"Closed connection between Client: %d and Server: %d\n", addr, dest);
         }
      }
   }

   // command error_t release(socket_t fd);

   // command error_t listen(socket_t fd);

   command void Transport.setServer() {

      socket_store_t socket;
      //socket_addr_t address;
      
      //address.port = 19;
      //address.addr = TOS_NODE_ID;

      socket.src.port = 19;
      socket.src.addr = TOS_NODE_ID;                
      socket.state = LISTEN;
      call socketCache.pushback(socket);
   }

   command void Transport.setClient() {
      
      socket_store_t socket;
      //socket_addr_t address;
      
      //address.port = 17;
      //address.addr = TOS_NODE_ID;

      socket.dest.port = 19;
      socket.dest.addr = 1;                  //what is this for?? (this is the server address, but how do we choose this?)      
      socket.src.port = 17;
      socket.src.addr = TOS_NODE_ID;        
      call socketCache.pushback(socket);

      call Transport.connect(socket);
   }

   //unit8_t* payload => tcpP* payload 
	command void Transport.makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
   }

}