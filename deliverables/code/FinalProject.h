
#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H


/*********** MESSAGE TYPE **********/

typedef nx_struct radio_route_msg {
	nx_uint16_t message_type;
	nx_uint16_t id;
	nx_uint16_t topic;
	nx_uint16_t payload;
} radio_route_msg_t;


/****** ADDITIONAL DEFINITIONS *****/

typedef struct Node{
	uint16_t id;
	struct Node* next;
} Node;


/********** CONSTANTS *********/
enum{
	AM_RADIO_COUNT_MSG = 10,
	ACK_TIMEOUT = 500,
	PUB_INTERVAL = 200,
	SEND_INTERVAL = 100,
	PACKET_POOL_SIZE = 20,
	TEMP_TOPIC = 0,
	HUM_TOPIC = 1,
	LUM_TOPIC =2,
	CONNECT = 0,
	CONNACK = 1,
	SUB = 2,
	SUBACK = 3,
	PUBLISH = 4
};

#endif
