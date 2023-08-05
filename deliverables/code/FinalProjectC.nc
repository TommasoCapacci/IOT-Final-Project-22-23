
#include "Timer.h"
#include "FinalProject.h"


module FinalProject @safe() {
  uses {
  
    /****** INTERFACES *****/
    
	  interface Boot;
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface Timer<TMilli> as Timer2;
    interface Packet;
    interface Random;
    
  }
} implementation {
  
  
  /****** VARIABLES *****/
  
  // Packets queue
  message_t* packetsPool[PACKET_POOL_SIZE];
  uint16_t addressesPool[PACKET_POOL_SIZE];
  uint8_t head = 0;
  uint8_t tail = 0;
  
  // Variables for retransmission
  message_t* request;
  uint16_t requestAddress = 0;
  
  // Data structures for connections and subscriptions
  Node* connections = NULL;
  Node* subscriptions[3] = {NULL, NULL, NULL};

  // Additional variables
  uint16_t counter = 0;
  char* topics[3] = {"field1", "field2", "field3"};
  
  
  /****** FUNCTION PROTOTYPES *****/
  
  void generate_send (uint16_t address, uint16_t message_type, uint16_t id, uint16_t topic, uint16_t payload);
  void handleRetransmission(uint16_t address, message_t* message);

  void printPacketDebug(radio_route_msg_t* payload);

  bool searchID(Node* list, uint8_t node_id);
  Node* addNode(Node* list, uint8_t node_id);
  void printList(Node* list);

  void handleCONNECT(radio_route_msg_t* payload);
  void handleCONNACK(radio_route_msg_t* payload);
  void handleSUB(radio_route_msg_t* payload);
  void handleSUBACK(radio_route_msg_t* payload);
  void handlePUBLISH(radio_route_msg_t* payload);
  
  
  /****** FUNCTIONS *****/
  
  void generate_send (uint16_t address, uint16_t message_type, uint16_t id, uint16_t topic, uint16_t payload){
  /*
  * Allocate a new message, populate it with the specified parameters and add it to the packets queue's head
  */
    message_t* message = (message_t*) malloc(sizeof(message_t));
    radio_route_msg_t* packet = (radio_route_msg_t*)call Packet.getPayload(message, sizeof(radio_route_msg_t));
  
    packet->message_type = message_type;
    packet->id = id;
    packet->topic = topic;
    packet->payload = payload;
  	
  	atomic{
  	  packetsPool[head] = message;
  	  addressesPool[head] = address;
 	  head = (head + 1) % PACKET_POOL_SIZE;
  	}
  } 
  
  void handleRetransmission(uint16_t address, message_t* message){
  /*
  * Handle retransmission of the specified packet
  */
    request = (message_t*) malloc(sizeof(message_t));
    memcpy(request, message, sizeof(message_t));
    requestAddress = address;
    call Timer0.startOneShot(ACK_TIMEOUT);
  }
  
  void printPacketDebug(radio_route_msg_t* payload){
  /*
  * Print packet's content in a structured way
  */
    dbg_clear("Data", "\tPacket type: %d\n", payload->message_type);
    dbg_clear("Data", "\tPacket id: %d\n", payload->id);
    dbg_clear("Data", "\tPacket topic: %d\n", payload->topic);
    dbg_clear("Data", "\tPacket payload: %d\n", payload->payload);
  }

  bool searchID(Node* list, uint8_t node_id){
  /*
  * Search a node inside the specified list
  */
    Node* current = list;

    while (current != NULL){
      if (current->id == node_id)
        return TRUE;
      current = current->next;
    }
    return FALSE;
  }

  Node* addNode(Node* list, uint8_t node_id){
  /*
  * Add a node to the head of the specified list
  */
    Node* newNode = (Node*)malloc(sizeof(Node));

    if(searchID(list, node_id))
      return list;
      
    newNode->id = node_id;
    newNode->next = list;
    return newNode;
  }

  void printList(Node* list){
  /*
  * Print all the nodes inside the specified list
  */
    Node* current = list;

    while (current != NULL){
      dbg_clear("Data", "\tNode id: %d\n", current->id);
      current = current->next;
    }
  }

  void handleCONNECT(radio_route_msg_t* payload){
    connections = addNode(connections, payload->id);
    dbg("Data", "Printing list of active connections:\n");
    printList(connections);
    
    generate_send(payload->id, CONNACK, payload->id, 0, 0);
  } 

  void handleCONNACK(radio_route_msg_t* payload){
    if (request != NULL){
      call Timer0.stop();
      free(request);
      request = NULL;

      // generate and send subscription request
      if(TOS_NODE_ID >= 2 && TOS_NODE_ID <= 4)
        payload->topic = 0;
      else if(TOS_NODE_ID >= 5 && TOS_NODE_ID <= 7)
        payload->topic = 1;
      else
        payload->topic = 2;
        
      generate_send(1, SUB, TOS_NODE_ID, payload->topic, 0);
    }
  }

  void handleSUB(radio_route_msg_t* payload){
    if (searchID(connections, payload->id)){ //check that sender is properly connected
      subscriptions[payload->topic] = addNode(subscriptions[payload->topic], payload->id);
      dbg("Data", "Printing list of subscriptions on topic %d:\n", payload->topic);
      printList(subscriptions[payload->topic]);
      
      generate_send(payload->id, SUBACK, payload->id, payload->topic, 0);
    }
  }

  void handleSUBACK(radio_route_msg_t* payload){
    if (request != NULL){
      call Timer0.stop();
      free(request);
      request = NULL;
      
      // generate publish request: we assumed that each mote has to be subscribed to a topic before starting to publish
      call Timer1.startPeriodic(PUB_INTERVAL);
    }
  }

  void handlePUBLISH(radio_route_msg_t* payload){
    Node* temp = NULL;
    
    if (TOS_NODE_ID == 1){  //if PANC...
      // print packet's content
      dbg_clear("Data_console", "{\"id\":%d, \"topic\":\"channels/2232092/publish\", \"payload\":\"%s=%d&status=MQTTPUBLISH\"}\n", payload->id, topics[payload->topic], payload->payload);
    
	    // forward the message to all the RIGHT subscribers
      temp = subscriptions[payload->topic];
      while (temp != NULL){
        if (temp->id != payload->id){  //assume that publish messages are not sent back to the publisher
          generate_send(temp->id, PUBLISH, payload->id, payload->topic, payload->payload);
          temp = temp->next;
        }
      } 
    }
  } 
  
  
  /****** EVENT HANDLERS *****/
  
  event void Boot.booted() {
    dbg("Boot","Application booted.\n");
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
  	if (err == SUCCESS){
  	  call Timer2.startPeriodic(SEND_INTERVAL);
      dbg("Radio","Radio on!\n");

      if (TOS_NODE_ID != 1) // if not PANC, send connect message to PANC
        generate_send(1, CONNECT, TOS_NODE_ID, 0, 0);
    } else {
      dbgerror("Radio", "Radio failed to start, retrying...\n");
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    dbg("Radio", "Radio stopped!\n");
  }
  
  event void Timer0.fired() {
  /*
  * Timer used to trigger retransmissions
  */
    radio_route_msg_t* packet = (radio_route_msg_t*)call Packet.getPayload(request, sizeof(radio_route_msg_t));
    
  	dbgerror("Timer", "Request was not acknowledged in time. Resending.\n");
    generate_send(requestAddress, packet->message_type, packet->id, packet->topic, packet->payload);
  }
  
  event void Timer1.fired() {
  /*
  * Timer used to trigger pubblications
  */
    uint16_t topic;
    
    counter++;
    if(TOS_NODE_ID >= 2 && TOS_NODE_ID <= 4)
        topic = 1;
      else if(TOS_NODE_ID >= 5 && TOS_NODE_ID <= 7)
        topic = 2;
      else
        topic = 0;
        
    dbg("Timer", "Publishing a message on topic %d. \n", topic);
    generate_send(1, PUBLISH, TOS_NODE_ID, topic, counter);
  }
  
  event void Timer2.fired() {
  /*
  * Timer used to send queued messages
  */
    atomic{
      if(head != tail){
        if (call AMSend.send(addressesPool[tail], packetsPool[tail], sizeof(radio_route_msg_t)) == SUCCESS)
	        dbg("Radio_send", "Sending packet to %d at time %s:\n", addressesPool[tail], sim_time_string());
    	  else 
	        dbgerror("Radio_send", "@@@FAILED@@@ Sending packet to %d at time %s:\n", addressesPool[tail], sim_time_string());
	  }
    }
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
	  radio_route_msg_t* packet = (radio_route_msg_t*) payload;
	
      dbg("Radio_recv", "Received packet at time %s:\n", sim_time_string());
      printPacketDebug(packet);
    
      switch (packet->message_type){
        case CONNECT:
          handleCONNECT(packet);
        break;
        case CONNACK:
          handleCONNACK(packet);
        break;
        case SUB:
          handleSUB(packet);
        break;
        case SUBACK:
          handleSUBACK(packet);
        break;
        case PUBLISH:
          handlePUBLISH(packet);
        break;
      }

      return bufPtr;
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
  /*  
  *  Check if the RIGHT packet has been sent
  */ 
	  radio_route_msg_t* packet;
	
    atomic{
      if (bufPtr == packetsPool[tail]){
      	packet = (radio_route_msg_t*)call Packet.getPayload(packetsPool[tail], sizeof(radio_route_msg_t));
      	if (packet->message_type == CONNECT || packet->message_type == SUB)
      	  handleRetransmission(addressesPool[tail], packetsPool[tail]);
      	  
        free(packetsPool[tail]);
        tail = (tail + 1) % PACKET_POOL_SIZE;
      }
    }
  }
}
