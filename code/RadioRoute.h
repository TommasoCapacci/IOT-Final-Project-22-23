#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H


/*********** MESSAGE TYPE **********/

typedef nx_struct radio_route_msg {
	uint16_t id;
	uint16_t message_type;
	uint16_t topic;
	uint16_t payload;
} radio_route_msg_t;


/****** ADDITIONAL DEFINITIONS *****/

  typedef struct {
    uint16_t id;
    Node* next;
  } Node;

enum{
  AM_RADIO_COUNT_MSG = 10,
  ACK_INTERVAL = 500,
  
  // Message constants
  CONNECT = 0,
  CONNACK = 1,
  SUB = 2,
  SUBACK = 3,
  PUBLISH = 4
};

#endif
