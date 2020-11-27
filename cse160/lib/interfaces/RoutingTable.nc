interface RoutingTable {
    command void start();
    //command uint16_t nextHop(uint16_t dest);
    command void print();
    command uint16_t retrieveNextHop(uint16_t dest);
}