#ifndef __SOCKET_H__
#define __SOCKET_H__

enum{
    MAX_NUM_OF_SOCKETS = 10,
    ROOT_SOCKET_ADDR = 255,
    ROOT_SOCKET_PORT = 255,
    SOCKET_BUFFER_SIZE = 128,
};

enum socket_state{
    CLOSED,
    LISTEN,
    ESTABLISHED,
    SYN_SENT,
    SYN_RCVD,
};

//An external structure can only contain external types aselements

/*  
endianness is the order or sequence of bytes of a word of digital data in computer memory. 
Endianness is primarily expressed as big-endian (BE) or little-endian (LE). 
A big-endian system stores the most significant byte of a word at the smallest
 memory address and the least significant byte at the largest. A little-endian system, 
 in contrast, stores the least-significant byte at the smallest address. Endianness may 
 also be used to describe the order in which the bits are transmitted over a communication channel. 
 Bit-endianess is seldom used in other contexts. 

The nx types are big-endian, the nxle types are little endian, the int types are signed and the uint types are unsigned. 
Note that these types are not keywords.•External array types are any array built from an external type, using the usual 
C syntax, e.g,nxint16t x[10].External structures and unions are declared like C structures and unions, but using the nx struct and nx union keywords. 
An external structure can only contain external types aselements. Currently, external structures and unions cannot contain bitfields.
*/

typedef nx_uint8_t nx_socket_port_t;
typedef uint8_t socket_port_t;

// socket_addr_t is a simplified version of an IP connection.
typedef nx_struct socket_addr_t{
    nx_socket_port_t port;
    nx_uint16_t addr;
}socket_addr_t;


// File descripter id. Each id is associated with a socket_store_t
typedef uint8_t socket_t;

// State of a socket. 
typedef struct socket_store_t{
    uint8_t flag;
    enum socket_state state;
    socket_addr_t src;
    socket_addr_t dest;

    // This is the sender portion.
    uint8_t sendBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastWritten;
    uint8_t lastAck;
    uint8_t lastSent;

    // This is the receiver portion
    uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastRead;
    uint8_t lastRcvd;
    uint8_t nextExpected;

    uint16_t RTT;
    uint8_t effectiveWindow;
}socket_store_t;

#endif
