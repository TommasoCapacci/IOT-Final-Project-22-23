#include "Timer.h"
#include "RadioRoute.h"


module RadioRouteC @safe() {


  /****** INTERFACES *****/

  uses {
    interface Boot;
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface Packet;
    interface Random;
  }

} implementation {
  

  /****** VARIABLES *******/

  message_t queued_message;
  radio_route_msg_t* packet;
  bool locked = FALSE;

  uint16_t requestAddress = 0;
  message_t* request;
  
  uint8_t topic = 0;
  uint8_t id = 0;
  Node* temp = NULL;

  Node* connections = NULL;
  Node* subscriptions[3] = {NULL, NULL, NULL};
  

  /****** FUNCTIONS PROTOTYPES*******/
  
  void printPacketDebug(radio_route_msg_t* payload);

  bool searchID(Node* list, uint8_t node_id);
  Node* addNode(Node* list, uint8_t node_id);
  void printList(Node* list);

  void handleRetransmission(uint16_t address, message_t* message);
  void handleCONNECT(message_t* message);
  void handleCONNACK(message_t* message);
  void handleSUB(message_t* message);
  void handleSUBACK(message_t* message);
  void handlePUBLISH(message_t* message);

  bool generate_send(uint16_t address, message_t* message);
  

  /****** FUNCTIONS *******/
  
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

  void handleRetransmission(uint16_t address, message_t* message){
  /*
  * Handle retransmission of the specified packet
  */
    request = message;
    requestAddress = address;
    call Timer0.startOneShot(ACK_TIMEOUT);
  }

  void handleCONNECT(message_t* message){
    packet = (radio_route_msg_t*)call Packet.getPayload(message, sizeof(radio_route_msg_t));
    connections = addNode(connections, packet->id);
    dbg("Data", "Printing list of active connections:\n");
    printList(connections);
    packet->message_type = CONNACK;
    generate_send(packet->id, message);
  }

  void handleCONNACK(message_t* message){
    if (request != NULL){
      packet = (radio_route_msg_t*)call Packet.getPayload(request, sizeof(radio_route_msg_t));
      if (packet->message_type == CONNECT){
        call Timer0.stop();
        request = NULL;
      }

      // generate and send random subscription request
      packet = (radio_route_msg_t*)call Packet.getPayload(message, sizeof(radio_route_msg_t));
      packet->id = TOS_NODE_ID;
      packet->message_type = SUB;
      packet->topic = call Random.rand32() % 3;
      generate_send(1, message);
      handleRetransmission(1, message);

      // generate publish request
      call Timer1.startPeriodic(PUB_INTERVAL);
    }
  }

  void handleSUB(message_t* message){
  	packet = (radio_route_msg_t*)call Packet.getPayload(message, sizeof(radio_route_msg_t));
    id = packet->id;
    topic = packet->topic;
    if (searchID(connections, id)){
      subscriptions[topic] = addNode(subscriptions[topic], id);
      dbg("Data", "Printing list of subscriptions on topic %d:\n", topic);
      printList(subscriptions[topic]);
      packet->message_type = SUBACK;
      generate_send(id, message);
    }
  }

  void handleSUBACK(message_t* message){
    if (request != NULL){
      packet = (radio_route_msg_t*)call Packet.getPayload(request, sizeof(radio_route_msg_t));
      if (packet->message_type == SUB){
        call Timer0.stop();
        request = NULL;
      }
    }
  }

  void handlePUBLISH(message_t* message){
    if (TOS_NODE_ID == 1){
      packet = (radio_route_msg_t*)call Packet.getPayload(message, sizeof(radio_route_msg_t));
      id = packet->id;
      topic = packet->topic;
      temp = subscriptions[topic];
      while (temp != NULL){
        if (temp->id != id){
          generate_send(temp->id, message);
          temp = temp->next;
        }
      } 
    }
  }  

  bool generate_send(uint16_t address, message_t* message){
  /*
  * Send the specified message to the specified address
  */
    if (call AMSend.send(address, message, sizeof(radio_route_msg_t)) == SUCCESS){
      locked = TRUE;
      dbg("Radio_send", "Sending packet to %d at time %s:\n", address, sim_time_string());
      printPacketDebug(packet);
      return TRUE;
    }
    return FALSE;
  }
    
  
  /****** EVENT HANDLERS *******/
  
  event void Boot.booted() {
    dbg("Boot","Application booted.\n");
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS){
      dbg("Radio","Radio on on node %d!\n", TOS_NODE_ID);
      if (TOS_NODE_ID != 1){
        // send connect message to node 1 (even in broadcast, should be more realistic)
        packet = (radio_route_msg_t*)call Packet.getPayload(&queued_message, sizeof(radio_route_msg_t));
        packet->id = TOS_NODE_ID;
        packet->message_type = CONNECT;
        generate_send(AM_BROADCAST_ADDR, &queued_message);
        handleRetransmission(AM_BROADCAST_ADDR, &queued_message);
      }
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
  * Use this timer to handle retransmissions
  */
  	dbgerror("Timer", "Request was not acknowledged in time. Resending.\n");
    generate_send(requestAddress, request);
    call Timer0.startOneShot(ACK_TIMEOUT);
  }

  event void Timer1.fired() {
  /*
  * Use this timer to handle pubblications
  */
    packet = (radio_route_msg_t*)call Packet.getPayload(&queued_message, sizeof(radio_route_msg_t));
    packet->id = TOS_NODE_ID;
    packet->message_type = PUBLISH;
    packet->topic = call Random.rand32() % 3;
    packet->payload = call Random.rand32() % 101;
    dbg("Timer", "Publishing a message on topic %d. \n", packet->topic);
    generate_send(1, &queued_message);
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
  /*
  * Parse the received packet and prepare the relative response
  */
    queued_message = *bufPtr;
    packet = (radio_route_msg_t*)payload;
    
    dbg("Radio_rec", "Received packet at time %s:\n", sim_time_string());
    printPacketDebug(packet);
    
    switch (packet->message_type){
      case CONNECT:
        handleCONNECT(bufPtr);
      break;
      case CONNACK:
        handleCONNACK(bufPtr);
      break;
      case SUB:
        handleSUB(bufPtr);
      break;
      case SUBACK:
        handleSUBACK(bufPtr);
      break;
      case PUBLISH:
        handlePUBLISH(bufPtr);
      break;
    }

    return bufPtr;

  }
  
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
  /* 
  * Check if the right packet has been sent 
  */ 
    if (&queued_message == bufPtr) 
      locked = FALSE;
  }
}
