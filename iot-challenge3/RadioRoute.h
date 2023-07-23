

#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H

typedef nx_struct radio_route_msg {
	nx_uint8_t type;
	nx_uint8_t sender;
	nx_uint8_t destination;
	nx_uint8_t value;
	nx_uint8_t node_requested;
	nx_uint8_t cost;
} radio_route_msg_t;


/****** ADDITIONAL DEFINITIONS *****/
  typedef struct {
    uint16_t next_hop;
    uint16_t cost;
  } Route;

enum {
  AM_RADIO_COUNT_MSG = 10,
  // Message constants
  DATA_MESSAGE = 0,
  ROUTE_REQUEST = 1,
  ROUTE_REPLY = 2
};

#endif
