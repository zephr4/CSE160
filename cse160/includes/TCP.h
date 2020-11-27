#ifndef TCP_PACKET_H
#define TCP_PACKET_H

#include "protocol.h"
#include "channels.h"

#define SYN 2
#define SYN_ACK 3
#define ACK 4
#define FIN 5
#define FIN_ACK 6
#define DATA 7
#define DATA_ACK 8

enum{
	headerLength = 8,
	payloadSize = 12
};

typedef nx_struct tcpP{
	nx_uint8_t destPort;
	nx_uint8_t srcPort;
	nx_uint8_t seq;
	nx_uint8_t ack;
	nx_uint8_t prevAck;
	nx_uint8_t flags;
	nx_uint8_t window;
	nx_uint8_t payload[payloadSize];
}tcpP;

#endif